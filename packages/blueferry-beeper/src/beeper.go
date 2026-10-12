package main

import (
	"bytes"
	"context"
	"errors"
	"maunium.net/go/mautrix/bridgev2/bridgeconfig"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// Keep the registration on bbctl's supported generic bridgev2 type. Desktop
// requires that type to expose this custom connector's per-login account.
// Update only reversible metadata through bbctl's bridge-state API.
func setBeeperMetadata(ctx context.Context, cfg *bridgeconfig.Config, owner string) error {
	if cfg.AppService.Bot.Username != "sh-blueferrybot" {
		return errors.New("unexpected Beeper bridge registration")
	}
	user, domain, ok := strings.Cut(strings.TrimPrefix(owner, "@"), ":")
	if !ok || domain != "beeper.com" {
		return errors.New("unexpected Beeper account domain")
	}
	endpoint := "https://api.beeper.com/bridgebox/" + url.PathEscape(user) + "/bridge/sh-blueferry/bridge_state"
	ctx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewBufferString(`{"stateEvent":"STARTING","reason":"BLUEFERRY_STARTED","isSelfHosted":true,"bridgeType":"bridgev2"}`))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+cfg.AppService.ASToken)
	req.Header.Set("Content-Type", "application/json")
	client := &http.Client{Timeout: 15 * time.Second, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return errors.New("Beeper registration metadata update failed")
	}
	return nil
}
