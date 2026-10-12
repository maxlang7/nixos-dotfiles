package main

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"path"
	"sort"
	"sync"
	"time"

	"maunium.net/go/mautrix/bridgev2"
	"maunium.net/go/mautrix/bridgev2/database"
	"maunium.net/go/mautrix/bridgev2/networkid"
	"maunium.net/go/mautrix/bridgev2/simplevent"
	"maunium.net/go/mautrix/bridgev2/status"
	"maunium.net/go/mautrix/event"
)

type Client struct {
	c       *Connector
	login   *bridgev2.UserLogin
	meta    *LoginMetadata
	mu      sync.Mutex
	cancel  context.CancelFunc
	pending map[networkid.MessageID]bool
}

var _ bridgev2.NetworkAPI = (*Client)(nil)

func (cl *Client) IsLoggedIn() bool { return true }
func (cl *Client) IsThisUser(ctx context.Context, user networkid.UserID) bool {
	return string(user) == cl.c.Config.AccountID
}
func (cl *Client) LogoutRemote(ctx context.Context) { cl.Disconnect() }
func (cl *Client) Disconnect() {
	cl.mu.Lock()
	defer cl.mu.Unlock()
	if cl.cancel != nil {
		cl.cancel()
		cl.cancel = nil
	}
}
func (cl *Client) Connect(_ context.Context) {
	cl.mu.Lock()
	defer cl.mu.Unlock()
	if cl.cancel != nil {
		return
	}
	ctx, cancel := context.WithCancel(cl.c.br.BackgroundCtx)
	cl.cancel = cancel
	go func() {
		ticker := time.NewTicker(time.Duration(cl.c.Config.PollSeconds) * time.Second)
		defer ticker.Stop()
		for {
			if err := cl.sync(ctx); err != nil {
				cl.login.BridgeState.Send(status.BridgeState{StateEvent: status.StateTransientDisconnect, Message: "BlueFerry is unavailable or needs attention"})
			} else {
				cl.login.BridgeState.Send(status.BridgeState{StateEvent: status.StateConnected})
			}
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
			}
		}
	}()
}
func messageID(account string, m Message) (networkid.MessageID, error) {
	ts, err := time.Parse(time.RFC3339Nano, m.Timestamp)
	if err != nil || m.Handle == "" {
		return "", errors.New("message has no valid timestamp or handle")
	}
	return networkid.MessageID(digest(fmt.Sprintf("%s\x00%s\x00%s\x00%t", account, m.Handle, ts.UTC().Format(time.RFC3339Nano), m.Outgoing))), nil
}
func (cl *Client) key(route string) networkid.PortalKey {
	return networkid.PortalKey{ID: networkid.PortalID(route), Receiver: cl.login.ID}
}
func (cl *Client) sync(ctx context.Context) error {
	// Serialize reconciliation with sending so the outgoing history echo can't
	// arrive in Matrix before the framework saves the send response.
	cl.c.mu.Lock()
	defer cl.c.mu.Unlock()
	if err := cl.c.check(ctx); err != nil {
		return err
	}
	threads, err := cl.c.bus.Threads(ctx)
	if err != nil {
		return err
	}
	cl.mu.Lock()
	for _, t := range threads {
		route, err := routeID(cl.meta.Routes, t)
		if err != nil {
			cl.mu.Unlock()
			return err
		}
		r := cl.meta.Routes[route]
		r.Group = t.Group
		if r.Primary == "" && !t.Group && len(t.Recipients) > 0 {
			r.Primary = canonical(t.Recipients[0])
		}
		if !contains(r.Keys, t.Key) {
			r.Keys = append(r.Keys, t.Key)
		}
		for _, a := range aliases(t) {
			if !contains(r.Aliases, a) {
				r.Aliases = append(r.Aliases, a)
			}
		}
		cl.meta.Routes[route] = r
	}
	err = cl.login.Save(ctx)
	cl.mu.Unlock()
	if err != nil {
		return err
	}
	for _, t := range threads {
		cl.mu.Lock()
		route, err := routeID(cl.meta.Routes, t)
		cl.mu.Unlock()
		if err != nil {
			return err
		}
		res := cl.login.QueueRemoteEvent(&simplevent.ChatResync{EventMeta: simplevent.EventMeta{Type: bridgev2.RemoteEventChatResync, PortalKey: cl.key(route), CreatePortal: true}})
		if !res.Success {
			return errors.New("failed to queue conversation")
		}
		sort.SliceStable(t.Messages, func(i, j int) bool {
			a, _ := time.Parse(time.RFC3339Nano, t.Messages[i].Timestamp)
			b, _ := time.Parse(time.RFC3339Nano, t.Messages[j].Timestamp)
			return a.Before(b)
		})
		for _, m := range t.Messages {
			mid, err := messageID(cl.c.Config.AccountID, m)
			if err != nil {
				continue
			}
			existing, err := cl.c.br.DB.Message.GetAllPartsByID(ctx, cl.login.ID, mid)
			if err != nil {
				return err
			}
			if len(existing) > 0 {
				delete(cl.pending, mid)
				continue
			}
			if cl.pending[mid] {
				continue
			}
			ts, _ := time.Parse(time.RFC3339Nano, m.Timestamp)
			sender := canonical(m.Address)
			if sender == "" {
				sender = "unknown-" + route
			}
			body := m.Body
			if m.Truncated {
				body += "\n[BlueFerry retained a truncated message]"
			}
			if body == "" {
				body = "[No text retained by BlueFerry]"
			}
			res = cl.login.QueueRemoteEvent(&simplevent.PreConvertedMessage{EventMeta: simplevent.EventMeta{Type: bridgev2.RemoteEventMessage, PortalKey: cl.key(route), CreatePortal: true, Timestamp: ts, Sender: bridgev2.EventSender{IsFromMe: m.Outgoing, ForceDMUser: !t.Group, Sender: networkid.UserID(sender), SenderLogin: func() networkid.UserLoginID {
				if m.Outgoing {
					return cl.login.ID
				}
				return ""
			}()}}, ID: mid, Data: &bridgev2.ConvertedMessage{Parts: []*bridgev2.ConvertedMessagePart{{Type: event.EventMessage, Content: &event.MessageEventContent{MsgType: event.MsgText, Body: body}}}}})
			if !res.Success {
				return errors.New("failed to queue retained message")
			}
		}
	}
	return nil
}
func (cl *Client) thread(ctx context.Context, portal *bridgev2.Portal) (Thread, error) {
	cl.mu.Lock()
	route, ok := cl.meta.Routes[string(portal.ID)]
	cl.mu.Unlock()
	if !ok {
		return Thread{}, errors.New("unknown conversation")
	}
	threads, err := cl.c.bus.Threads(ctx)
	if err != nil {
		return Thread{}, err
	}
	return chooseThread(route, threads)
}
func (cl *Client) GetChatInfo(ctx context.Context, portal *bridgev2.Portal) (*bridgev2.ChatInfo, error) {
	t, err := cl.thread(ctx, portal)
	if err != nil {
		return nil, err
	}
	members := bridgev2.ChatMemberMap{}
	members.Set(bridgev2.ChatMember{EventSender: bridgev2.EventSender{IsFromMe: true, SenderLogin: cl.login.ID, Sender: networkid.UserID(cl.c.Config.AccountID)}, Membership: event.MembershipJoin})
	addresses := t.Members
	if !t.Group {
		cl.mu.Lock()
		r := cl.meta.Routes[string(portal.ID)]
		cl.mu.Unlock()
		addresses = []string{r.Primary}
	}
	for _, a := range addresses {
		a = canonical(a)
		if a != "" {
			info, err := cl.userInfo(ctx, a)
			if err != nil {
				return nil, err
			}
			members.Set(bridgev2.ChatMember{EventSender: bridgev2.EventSender{Sender: networkid.UserID(a)}, Membership: event.MembershipJoin, UserInfo: info})
		}
	}
	other := networkid.UserID("")
	if !t.Group && len(addresses) > 0 {
		other = networkid.UserID(addresses[0])
	}
	typ := database.RoomTypeDM
	if t.Group {
		typ = database.RoomTypeDefault
	}
	topic := "BlueFerry retained text messages. Attachments, reactions and edits are unavailable."
	if t.Group {
		topic += " Group replies are disabled."
	}
	return &bridgev2.ChatInfo{Name: &t.Name, Topic: &topic, Type: &typ, Members: &bridgev2.ChatMemberList{IsFull: false, OtherUserID: other, MemberMap: members, ExcludeChangesFromTimeline: true}, ExcludeChangesFromTimeline: true}, nil
}
func (cl *Client) GetUserInfo(ctx context.Context, ghost *bridgev2.Ghost) (*bridgev2.UserInfo, error) {
	return cl.userInfo(ctx, canonical(string(ghost.ID)))
}
func (cl *Client) userInfo(ctx context.Context, a string) (*bridgev2.UserInfo, error) {
	contacts, err := cl.c.bus.Contacts(ctx)
	if err != nil {
		return nil, err
	}
	name := a
	if contact, ok := contactFor(contacts, a); ok && contact.Name != "" {
		name = contact.Name
	}
	result := &bridgev2.UserInfo{Name: &name}
	photo, err := cl.c.bus.Photo(ctx, a)
	if err != nil {
		return result, nil
	}
	if len(photo) > 0 {
		mime := http.DetectContentType(photo)
		if mime == "image/jpeg" || mime == "image/png" {
			result.Avatar = &bridgev2.Avatar{ID: networkid.AvatarID(digest(string(photo))), Get: func(context.Context) ([]byte, error) { return photo, nil }}
		}
	}
	return result, nil
}
func (cl *Client) GetCapabilities(ctx context.Context, portal *bridgev2.Portal) *event.RoomFeatures {
	return &event.RoomFeatures{ID: "blueferry-text-v1", MaxTextLength: 256 * 1024}
}
func validateSend(t Thread, msg *bridgev2.MatrixMessage) error {
	if t.Group {
		return errors.New("BlueFerry group replies are disabled")
	}
	if !t.ReplyReady || len(t.Recipients) != 1 {
		return errors.New("BlueFerry conversation has no verified direct reply route")
	}
	if msg.Content.MsgType != event.MsgText || msg.Content.Body == "" {
		return errors.New("only non-empty text messages are supported")
	}
	if msg.ReplyTo != nil || msg.ThreadRoot != nil {
		return errors.New("quoted replies and threads are unsupported; send ordinary text")
	}
	if len(msg.Content.Body) > 256*1024 {
		return errors.New("text exceeds BlueFerry byte limit")
	}
	return nil
}
func (cl *Client) HandleMatrixMessage(ctx context.Context, msg *bridgev2.MatrixMessage) (*bridgev2.MatrixMessageResponse, error) {
	cl.c.mu.Lock()
	defer cl.c.mu.Unlock()
	if err := cl.c.check(ctx); err != nil {
		return nil, err
	}
	t, err := cl.thread(ctx, msg.Portal)
	if err != nil {
		return nil, err
	}
	if err = validateSend(t, msg); err != nil {
		return nil, err
	}
	if msg.Event == nil || cl.c.claim == nil {
		return nil, errors.New("send guard is unavailable")
	}
	if err = cl.c.claim(ctx, string(msg.Event.ID)); err != nil {
		return nil, err
	}
	transfer, err := cl.c.bus.Send(ctx, t.Key, msg.Content.Body)
	if err != nil {
		return nil, errors.New("BlueFerry send failed or outcome is unknown. Check your phone before retrying")
	}
	after, err := cl.thread(ctx, msg.Portal)
	if err != nil {
		return nil, errors.New("message was submitted; cannot confirm its history record. Check your phone before retrying")
	}
	for i := len(after.Messages) - 1; i >= 0; i-- {
		m := after.Messages[i]
		if m.Outgoing && m.Handle == path.Base(transfer) && m.Body == msg.Content.Body {
			mid, err := messageID(cl.c.Config.AccountID, m)
			if err != nil {
				return nil, err
			}
			ts, _ := time.Parse(time.RFC3339Nano, m.Timestamp)
			if cl.pending == nil {
				cl.pending = map[networkid.MessageID]bool{}
			}
			cl.pending[mid] = true
			return &bridgev2.MatrixMessageResponse{DB: &database.Message{ID: mid, SenderID: networkid.UserID(cl.c.Config.AccountID), Timestamp: ts}}, nil
		}
	}
	return nil, errors.New("message was submitted but the retained history record is missing. Check your phone before retrying")
}
