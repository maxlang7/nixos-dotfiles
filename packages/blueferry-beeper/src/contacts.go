package main

import (
	"context"
	"errors"
	"maunium.net/go/mautrix/bridgev2"
	"maunium.net/go/mautrix/bridgev2/networkid"
	"sort"
	"strings"
)

func (cl *Client) GetContactList(ctx context.Context) ([]*bridgev2.ResolveIdentifierResponse, error) {
	contacts, err := cl.c.bus.Contacts(ctx)
	if err != nil {
		return nil, err
	}
	addresses := make([]string, 0, len(contacts))
	for a := range contacts {
		addresses = append(addresses, a)
	}
	sort.Strings(addresses)
	out := make([]*bridgev2.ResolveIdentifierResponse, 0, len(addresses))
	for _, a := range addresses {
		c := contacts[a]
		name := c.Name
		if name == "" {
			name = a
		}
		out = append(out, &bridgev2.ResolveIdentifierResponse{UserID: networkid.UserID(a), UserInfo: &bridgev2.UserInfo{Name: &name}})
	}
	return out, nil
}
func (cl *Client) SearchUsers(ctx context.Context, query string) ([]*bridgev2.ResolveIdentifierResponse, error) {
	contacts, err := cl.GetContactList(ctx)
	if err != nil {
		return nil, err
	}
	query = strings.ToLower(strings.TrimSpace(query))
	var result []*bridgev2.ResolveIdentifierResponse
	for _, c := range contacts {
		if strings.Contains(strings.ToLower(*c.UserInfo.Name), query) || strings.Contains(strings.ToLower(string(c.UserID)), query) {
			result = append(result, c)
			if len(result) == 100 {
				break
			}
		}
	}
	return result, nil
}
func (cl *Client) ResolveIdentifier(ctx context.Context, identifier string, create bool) (*bridgev2.ResolveIdentifierResponse, error) {
	a := canonical(identifier)
	contacts, err := cl.c.bus.Contacts(ctx)
	if err != nil {
		return nil, err
	}
	contact, found := contacts[a]
	if !found {
		return nil, errors.New("identifier is absent from the paired phone's contacts")
	}
	name := contact.Name
	if name == "" {
		name = a
	}
	result := &bridgev2.ResolveIdentifierResponse{UserID: networkid.UserID(a), UserInfo: &bridgev2.UserInfo{Name: &name}}
	if create {
		threads, err := cl.c.bus.Threads(ctx)
		if err != nil {
			return nil, err
		}
		var matches []Thread
		for _, t := range threads {
			if !t.Group && contains(aliases(t), a) {
				matches = append(matches, t)
			}
		}
		if len(matches) != 1 {
			return nil, errors.New("BlueFerry can reply only to an existing unambiguous retained conversation")
		}
		cl.mu.Lock()
		route, err := routeID(cl.meta.Routes, matches[0])
		_, known := cl.meta.Routes[route]
		cl.mu.Unlock()
		if err != nil {
			return nil, err
		}
		if !known {
			return nil, errors.New("conversation import is still in progress")
		}
		result.Chat = &bridgev2.CreateChatResponse{PortalKey: cl.key(route)}
	}
	return result, nil
}
