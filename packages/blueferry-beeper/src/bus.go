package main

import (
	"context"
	"encoding/json"
	"errors"
	"github.com/godbus/dbus/v5"
	"sync"
	"time"
)

const busName = "io.weirdware.BlueFerry"
const busPath = "/io/weirdware/BlueFerry"
const busInterface = "io.weirdware.BlueFerry.Messages1"
const maxJSONBytes = 8 * 1024 * 1024

type Message struct {
	Handle    string `json:"handle"`
	Address   string `json:"address"`
	Body      string `json:"body"`
	Timestamp string `json:"timestamp"`
	Outgoing  bool   `json:"outgoing"`
	Truncated bool   `json:"body_truncated"`
	Sender    string `json:"sender"`
}
type Thread struct {
	Key        string    `json:"key"`
	Name       string    `json:"name"`
	Aliases    []string  `json:"aliases"`
	Members    []string  `json:"members"`
	Recipients []string  `json:"recipients"`
	Group      bool      `json:"is_group"`
	ReplyReady bool      `json:"reply_ready"`
	Messages   []Message `json:"messages"`
}
type Contact struct {
	Name   string   `json:"name"`
	Phones []string `json:"phones"`
	Emails []string `json:"emails"`
}
type Backend interface {
	JSON(context.Context, string, any, ...any) error
	Threads(context.Context) ([]Thread, error)
	Contacts(context.Context) (map[string]Contact, error)
	Photo(context.Context, string) ([]byte, error)
	Send(context.Context, string, string) (string, error)
	Close() error
}
type Bus struct {
	conn          *dbus.Conn
	cacheMu       sync.Mutex
	contactsCache map[string]Contact
	contactsUntil time.Time
	photos        map[string]photoCache
}
type photoCache struct {
	data  []byte
	until time.Time
}

func openBus() (*Bus, error) {
	conn, err := dbus.ConnectSessionBus()
	if err != nil {
		return nil, err
	}
	return &Bus{conn: conn}, nil
}
func (b *Bus) Close() error { return b.conn.Close() }
func (b *Bus) JSON(ctx context.Context, method string, output any, args ...any) error {
	ctx, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()
	var raw string
	if err := b.conn.Object(busName, dbus.ObjectPath(busPath)).CallWithContext(ctx, busInterface+"."+method, 0, args...).Store(&raw); err != nil {
		return err
	}
	if len(raw) > maxJSONBytes {
		return errors.New("BlueFerry response exceeded size limit")
	}
	return json.Unmarshal([]byte(raw), output)
}
func (b *Bus) Threads(ctx context.Context) ([]Thread, error) {
	var result []Thread
	err := b.JSON(ctx, "ListThreads", &result, uint32(1000))
	return result, err
}
func (b *Bus) Contacts(ctx context.Context) (map[string]Contact, error) {
	b.cacheMu.Lock()
	defer b.cacheMu.Unlock()
	if time.Now().Before(b.contactsUntil) {
		return b.contactsCache, nil
	}
	result := map[string]Contact{}
	ambiguous := map[string]bool{}
	for offset := uint32(0); offset < 10000; offset += 150 {
		var page []Contact
		if err := b.JSON(ctx, "ListContacts", &page, offset, uint32(150)); err != nil {
			return nil, err
		}
		for _, c := range page {
			for _, a := range append(c.Phones, c.Emails...) {
				key := canonical(a)
				if ambiguous[key] {
					continue
				}
				if old, found := result[key]; found && old.Name != c.Name {
					result[key] = Contact{}
					ambiguous[key] = true
					continue
				}
				result[key] = c
			}
		}
		if len(page) < 150 {
			b.contactsCache = result
			b.contactsUntil = time.Now().Add(time.Minute)
			return result, nil
		}
	}
	return nil, errors.New("contact list exceeds bridge limit")
}
func (b *Bus) Photo(ctx context.Context, address string) ([]byte, error) {
	b.cacheMu.Lock()
	defer b.cacheMu.Unlock()
	if cached, ok := b.photos[address]; ok && time.Now().Before(cached.until) {
		return cached.data, nil
	}
	ctx, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()
	var result []byte
	err := b.conn.Object(busName, dbus.ObjectPath(busPath)).CallWithContext(ctx, busInterface+".GetContactPhoto", 0, address).Store(&result)
	if len(result) > 1024*1024 {
		return nil, errors.New("contact photo exceeds bridge limit")
	}
	if err == nil {
		if b.photos == nil {
			b.photos = map[string]photoCache{}
		}
		if len(b.photos) >= 128 {
			b.photos = map[string]photoCache{}
		}
		b.photos[address] = photoCache{data: result, until: time.Now().Add(time.Minute)}
	}
	return result, err
}
func (b *Bus) Send(ctx context.Context, key, body string) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, 240*time.Second)
	defer cancel()
	var transfer string
	err := b.conn.Object(busName, dbus.ObjectPath(busPath)).CallWithContext(ctx, busInterface+".SendToThreadChecked", 0, key, body, false, "").Store(&transfer)
	return transfer, err
}
