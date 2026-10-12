package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"os"
	"strings"
	"sync"
	"time"

	"go.mau.fi/util/configupgrade"
	"maunium.net/go/mautrix/bridgev2"
	"maunium.net/go/mautrix/bridgev2/database"
	"maunium.net/go/mautrix/bridgev2/networkid"
	"maunium.net/go/mautrix/id"
)

type Config struct {
	Owner       string `yaml:"owner"`
	AccountID   string `yaml:"account_id"`
	DeviceEnv   string `yaml:"device_env"`
	PollSeconds int    `yaml:"poll_seconds"`
}
type Route struct {
	Keys    []string `json:"keys"`
	Aliases []string `json:"aliases"`
	Group   bool     `json:"group"`
	Primary string   `json:"primary"`
}
type LoginMetadata struct {
	Routes map[string]Route `json:"routes"`
}
type Connector struct {
	br     *bridgev2.Bridge
	Config Config
	bus    Backend
	mu     sync.Mutex
	claim  func(context.Context, string) error
}

var _ bridgev2.NetworkConnector = (*Connector)(nil)

func (c *Connector) Init(br *bridgev2.Bridge) { c.br = br }
func (c *Connector) Start(ctx context.Context) error {
	c.claim = func(ctx context.Context, eventID string) error {
		return claimSend(ctx, c.br.DB, string(c.br.ID), c.Config.AccountID, eventID)
	}
	b, err := openBus()
	c.bus = b
	return err
}
func (c *Connector) Stop() {
	if c.bus != nil {
		_ = c.bus.Close()
	}
}
func (c *Connector) GetName() bridgev2.BridgeName {
	return bridgev2.BridgeName{DisplayName: "BlueFerry", NetworkURL: "https://github.com/erikwb/blueferry", NetworkID: "blueferry", BeeperBridgeType: "blueferry", DefaultPort: 29388, DefaultCommandPrefix: "!bf"}
}
func (c *Connector) GetDBMetaTypes() database.MetaTypes {
	return database.MetaTypes{UserLogin: func() any { return &LoginMetadata{Routes: map[string]Route{}} }}
}
func (c *Connector) GetCapabilities() *bridgev2.NetworkGeneralCapabilities {
	return &bridgev2.NetworkGeneralCapabilities{Provisioning: bridgev2.ProvisioningCapabilities{ResolveIdentifier: bridgev2.ResolveIdentifierCapabilities{ContactList: true, LookupPhone: true, LookupEmail: true, Search: true, CreateDM: true}}}
}
func (c *Connector) GetBridgeInfoVersion() (int, int) { return 3, 1 }
func (c *Connector) GetConfig() (string, any, configupgrade.Upgrader) {
	return "owner: ''\naccount_id: ''\ndevice_env: ''\npoll_seconds: 15\n", &c.Config, configupgrade.SimpleUpgrader(func(h configupgrade.Helper) {
		h.Copy(configupgrade.Str, "owner")
		h.Copy(configupgrade.Str, "account_id")
		h.Copy(configupgrade.Str, "device_env")
		h.Copy(configupgrade.Int, "poll_seconds")
	})
}
func (c *Connector) ValidateConfig() error {
	if !strings.HasPrefix(c.Config.Owner, "@") || !strings.Contains(c.Config.Owner, ":") {
		return errors.New("network.owner must be your Beeper Matrix user ID")
	}
	if c.Config.AccountID == "" || c.Config.DeviceEnv == "" {
		return errors.New("network.account_id and device_env are required")
	}
	if c.Config.PollSeconds < 5 || c.Config.PollSeconds > 300 {
		return errors.New("poll_seconds must be between 5 and 300")
	}
	return nil
}
func phoneID(path string) (string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	for _, line := range strings.Split(string(data), "\n") {
		if strings.HasPrefix(line, "BLUEFERRY_MAC=") {
			v := strings.TrimSpace(strings.TrimPrefix(line, "BLUEFERRY_MAC="))
			if len(v) != 17 {
				return "", errors.New("invalid BlueFerry device binding")
			}
			return "bf-" + digest(strings.ToUpper(v)), nil
		}
	}
	return "", errors.New("BlueFerry device binding missing")
}
func (c *Connector) check(ctx context.Context) error {
	bound, err := phoneID(c.Config.DeviceEnv)
	if err != nil {
		return err
	}
	if bound != c.Config.AccountID {
		return errors.New("BlueFerry phone changed; bridge requires a separate account")
	}
	var s struct {
		APIVersion int  `json:"api_version"`
		MAP        bool `json:"map"`
	}
	if err = c.bus.JSON(ctx, "GetStatus", &s); err != nil {
		return err
	}
	if s.APIVersion < 2 {
		return errors.New("BlueFerry API v2 is required")
	}
	if !s.MAP {
		return errors.New("BlueFerry messaging is disconnected")
	}
	return nil
}
func (c *Connector) LoadUserLogin(ctx context.Context, login *bridgev2.UserLogin) error {
	if string(login.ID) != c.Config.AccountID || string(login.UserMXID) != c.Config.Owner {
		return errors.New("login does not match configured owner and device")
	}
	meta := login.Metadata.(*LoginMetadata)
	if meta.Routes == nil {
		meta.Routes = map[string]Route{}
	}
	login.Client = &Client{c: c, login: login, meta: meta}
	return nil
}
func (c *Connector) GetLoginFlows() []bridgev2.LoginFlow {
	return []bridgev2.LoginFlow{{ID: "local", Name: "Paired BlueFerry phone", Description: "Use the phone already paired with this desktop"}}
}
func (c *Connector) CreateLogin(ctx context.Context, user *bridgev2.User, flow string) (bridgev2.LoginProcess, error) {
	if string(user.MXID) != c.Config.Owner || flow != "local" {
		return nil, errors.New("this bridge is restricted to its configured owner")
	}
	return &Login{c: c, user: user}, nil
}

type Login struct {
	c    *Connector
	user *bridgev2.User
}

func (l *Login) Cancel() {}
func (l *Login) Start(ctx context.Context) (*bridgev2.LoginStep, error) {
	if err := l.c.check(ctx); err != nil {
		return nil, err
	}
	existing, err := l.c.br.GetExistingUserLoginByID(ctx, networkid.UserLoginID(l.c.Config.AccountID))
	if err != nil {
		return nil, err
	}
	if existing != nil {
		if existing.UserMXID != l.user.MXID {
			return nil, errors.New("phone belongs to another bridge user")
		}
		existing.Client.Connect(ctx)
		return &bridgev2.LoginStep{Type: bridgev2.LoginStepTypeComplete, StepID: "blueferry.complete", CompleteParams: &bridgev2.LoginCompleteParams{UserLoginID: existing.ID, UserLogin: existing}}, nil
	}
	login, err := l.user.NewLogin(ctx, &database.UserLogin{ID: networkid.UserLoginID(l.c.Config.AccountID), RemoteName: "BlueFerry iPhone"}, nil)
	if err != nil {
		return nil, err
	}
	login.Client.Connect(ctx)
	return &bridgev2.LoginStep{Type: bridgev2.LoginStepTypeComplete, StepID: "blueferry.complete", CompleteParams: &bridgev2.LoginCompleteParams{UserLoginID: login.ID, UserLogin: login}}, nil
}
func (c *Connector) AutoLogin() {
	ctx := c.br.BackgroundCtx
	for {
		if err := c.check(ctx); err == nil {
			user, err := c.br.GetUserByMXID(ctx, id.UserID(c.Config.Owner))
			if err == nil {
				_, err = (&Login{c: c, user: user}).Start(ctx)
			}
			if err == nil {
				return
			}
			c.br.Log.Warn().Msg("BlueFerry login failed; retrying")
		}
		select {
		case <-ctx.Done():
			return
		case <-time.After(15 * time.Second):
		}
	}
}
func digest(s string) string { hash := sha256.Sum256([]byte(s)); return hex.EncodeToString(hash[:16]) }
func canonical(s string) string {
	s = strings.TrimSpace(s)
	s = strings.TrimPrefix(s, "address:")
	s = strings.TrimPrefix(s, "phone:")
	s = strings.TrimPrefix(s, "email:")
	if strings.Contains(s, "@") {
		return strings.ToLower(s)
	}
	return strings.Map(func(r rune) rune {
		if strings.ContainsRune(" ()-.\t\n", r) {
			return -1
		}
		return r
	}, s)
}
func contains(values []string, value string) bool {
	for _, v := range values {
		if v == value {
			return true
		}
	}
	return false
}
func aliases(t Thread) []string {
	var out []string
	for _, a := range append(t.Aliases, t.Recipients...) {
		a = canonical(a)
		if a != "" && !contains(out, a) {
			out = append(out, a)
		}
	}
	return out
}
func routeID(routes map[string]Route, t Thread) (string, error) {
	for id, r := range routes {
		if contains(r.Keys, t.Key) {
			return id, nil
		}
	}
	var found string
	if !t.Group {
		for id, r := range routes {
			if r.Group {
				continue
			}
			for _, a := range aliases(t) {
				if contains(r.Aliases, a) {
					if found != "" && found != id {
						return "", errors.New("ambiguous contact merge; refusing to route")
					}
					found = id
				}
			}
		}
	}
	if found != "" {
		return found, nil
	}
	return digest(t.Key), nil
}
func chooseThread(route Route, threads []Thread) (Thread, error) {
	var matches []Thread
	for _, t := range threads {
		if t.Group != route.Group {
			continue
		}
		matched := contains(route.Keys, t.Key)
		if !matched && !t.Group {
			for _, a := range aliases(t) {
				if contains(route.Aliases, a) {
					matched = true
				}
			}
		}
		if matched {
			matches = append(matches, t)
		}
	}
	if len(matches) != 1 {
		return Thread{}, errors.New("conversation is missing or ambiguous; refusing to guess a recipient")
	}
	return matches[0], nil
}
