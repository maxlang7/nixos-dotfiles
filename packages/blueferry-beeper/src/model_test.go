package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"github.com/godbus/dbus/v5"
	_ "github.com/mattn/go-sqlite3"
	"maunium.net/go/mautrix/bridgev2"
	"maunium.net/go/mautrix/bridgev2/database"
	"maunium.net/go/mautrix/bridgev2/networkid"
	"maunium.net/go/mautrix/event"
	"os"
	"path/filepath"
	"testing"
)

func TestMessageIdentity(t *testing.T) {
	a := Message{Handle: "1", Timestamp: "2026-10-12T01:00:00Z"}
	b := a
	b.Timestamp = "2026-10-11T21:00:00-04:00"
	x, e := messageID("phone1", a)
	y, f := messageID("phone1", b)
	if e != nil || f != nil || x != y {
		t.Fatal("equivalent instants must deduplicate")
	}
	b.Timestamp = "2026-10-13T01:00:00Z"
	y, _ = messageID("phone1", b)
	if x == y {
		t.Fatal("reused handles must remain distinct")
	}
	y, _ = messageID("phone2", a)
	if x == y {
		t.Fatal("phone namespaces collided")
	}
	a.Timestamp = "invalid"
	if _, e = messageID("phone1", a); e == nil {
		t.Fatal("accepted malformed timestamp")
	}
}
func TestRouting(t *testing.T) {
	routes := map[string]Route{"stable": {Keys: []string{"old"}, Aliases: []string{"+15550000000"}}}
	thread := Thread{Key: "new", Aliases: []string{"+1 (555) 000-0000"}, Recipients: []string{"+15550000000"}}
	r, e := routeID(routes, thread)
	if e != nil || r != "stable" {
		t.Fatal("contact rename split room")
	}
	if _, e = chooseThread(routes["stable"], []Thread{thread, thread}); e == nil {
		t.Fatal("ambiguous send route accepted")
	}
	routes["other"] = Route{Aliases: []string{"person@example.test"}}
	thread.Aliases = append(thread.Aliases, "person@example.test")
	if _, e = routeID(routes, thread); e == nil {
		t.Fatal("two rooms merged silently")
	}
	thread.Group = true
	if r, e = routeID(routes, thread); e != nil || r == "stable" {
		t.Fatal("group was mapped to direct chat")
	}
}
func TestSendValidation(t *testing.T) {
	thread := Thread{ReplyReady: true, Recipients: []string{"+15550000000"}}
	msg := &bridgev2.MatrixMessage{}
	msg.Event = &event.Event{}
	msg.Event.ID = "$fixture"
	msg.Content = &event.MessageEventContent{MsgType: event.MsgText, Body: "Hello"}
	if err := validateSend(thread, msg); err != nil {
		t.Fatal(err)
	}
	thread.Group = true
	if validateSend(thread, msg) == nil {
		t.Fatal("group reply allowed")
	}
	thread.Group = false
	msg.Content.MsgType = event.MsgImage
	if validateSend(thread, msg) == nil {
		t.Fatal("attachment allowed")
	}
	msg.Content.MsgType = event.MsgText
	msg.Content.Body = ""
	if validateSend(thread, msg) == nil {
		t.Fatal("empty message allowed")
	}
	msg.Content.Body = "Hello"
	thread.Recipients = append(thread.Recipients, "+15550000001")
	if validateSend(thread, msg) == nil {
		t.Fatal("ambiguous recipients allowed")
	}
}
func TestPhoneBinding(t *testing.T) {
	p := filepath.Join(t.TempDir(), "local.env")
	if err := os.WriteFile(p, []byte("BLUEFERRY_MAC=00:11:22:33:44:55\n"), 0600); err != nil {
		t.Fatal(err)
	}
	a, e := phoneID(p)
	if e != nil || a == "" {
		t.Fatal(e)
	}
	os.WriteFile(p, []byte("BLUEFERRY_MAC=00:11:22:33:44:56\n"), 0600)
	b, _ := phoneID(p)
	if a == b {
		t.Fatal("phone change unrecognized")
	}
}

type fakeService struct{}

func (*fakeService) GetStatus() (string, *dbus.Error) { return `{"api_version":2,"map":true}`, nil }
func (*fakeService) ListThreads(limit uint32) (string, *dbus.Error) {
	if limit != 1000 {
		return "", dbus.MakeFailedError(os.ErrInvalid)
	}
	data, _ := json.Marshal([]Thread{{Key: "fixture", Name: "Fixture", Messages: []Message{{Handle: "1", Timestamp: "2026-10-12T01:00:00Z", Body: "test"}}}})
	return string(data), nil
}
func (*fakeService) ListContacts(offset, limit uint32) (string, *dbus.Error) {
	return `[{"name":"Fixture","phones":["+1 (555) 000-0000"],"emails":[]}]`, nil
}
func (*fakeService) GetContactPhoto(address string) ([]byte, *dbus.Error) {
	return []byte{1, 2, 3}, nil
}
func (*fakeService) SendToThreadChecked(key, body string, confirm bool, token string) (string, *dbus.Error) {
	if key != "fixture" || body != "test" || confirm || token != "" {
		return "", dbus.MakeFailedError(os.ErrInvalid)
	}
	return "/fake/transfer1", nil
}
func TestDBusContract(t *testing.T) {
	if os.Getenv("BLUEFERRY_TEST_BUS") != "1" {
		t.Skip("run under an isolated dbus-run-session with BLUEFERRY_TEST_BUS=1")
	}
	server, err := dbus.ConnectSessionBus()
	if err != nil {
		t.Fatal(err)
	}
	defer server.Close()
	if err = server.Export(&fakeService{}, dbus.ObjectPath(busPath), busInterface); err != nil {
		t.Fatal(err)
	}
	if _, err = server.RequestName(busName, dbus.NameFlagDoNotQueue); err != nil {
		t.Fatal(err)
	}
	b, err := openBus()
	if err != nil {
		t.Fatal(err)
	}
	defer b.Close()
	ctx := context.Background()
	ts, err := b.Threads(ctx)
	if err != nil || len(ts) != 1 {
		t.Fatal("thread contract", err)
	}
	contacts, err := b.Contacts(ctx)
	if err != nil || contacts["+15550000000"].Name != "Fixture" {
		t.Fatal("contacts contract", err)
	}
	if _, err = b.Photo(ctx, "+15550000000"); err != nil {
		t.Fatal(err)
	}
	if _, err = b.Send(ctx, "fixture", "test"); err != nil {
		t.Fatal(err)
	}
}
func TestContactLookup(t *testing.T) {
	contacts := map[string]Contact{"+15550000000": {Name: "Fixture"}, "15550000001": {Name: "Other"}}
	if c, ok := contactFor(contacts, "5550000000"); !ok || c.Name != "Fixture" {
		t.Fatal("NANP variant missing")
	}
	if _, ok := contactFor(contacts, "495550000000"); ok {
		t.Fatal("international suffix matched incorrectly")
	}
	if canonical("address:phone:15550000000") != "15550000000" {
		t.Fatal("typed alias was not unwrapped")
	}
}

type fakeBackend struct {
	threads []Thread
	sends   int
	sendErr bool
}

func (f *fakeBackend) Close() error { return nil }
func (f *fakeBackend) JSON(ctx context.Context, method string, out any, args ...any) error {
	return json.Unmarshal([]byte(`{"api_version":2,"map":true}`), out)
}
func (f *fakeBackend) Threads(context.Context) ([]Thread, error) { return f.threads, nil }
func (f *fakeBackend) Contacts(context.Context) (map[string]Contact, error) {
	return map[string]Contact{}, nil
}
func (f *fakeBackend) Photo(context.Context, string) ([]byte, error) { return nil, nil }
func (f *fakeBackend) Send(ctx context.Context, key, body string) (string, error) {
	f.sends++
	if f.sendErr {
		return "", os.ErrDeadlineExceeded
	}
	f.threads[0].Messages = append(f.threads[0].Messages, Message{Handle: "transfer1", Timestamp: "2026-10-12T01:00:00Z", Body: body, Outgoing: true})
	return "/fake/transfer1", nil
}
func TestCheckedSendAndUnknownOutcome(t *testing.T) {
	dir := t.TempDir()
	env := filepath.Join(dir, "env")
	os.WriteFile(env, []byte("BLUEFERRY_MAC=00:11:22:33:44:55\n"), 0600)
	account, _ := phoneID(env)
	backend := &fakeBackend{threads: []Thread{{Key: "fixture", Recipients: []string{"+15550000000"}, ReplyReady: true}}}
	connector := &Connector{claim: func(context.Context, string) error { return nil }, Config: Config{AccountID: account, DeviceEnv: env}, bus: backend}
	cl := &Client{c: connector, meta: &LoginMetadata{Routes: map[string]Route{"route": {Keys: []string{"fixture"}}}}}
	msg := &bridgev2.MatrixMessage{}
	msg.Event = &event.Event{}
	msg.Event.ID = "$fixture"
	msg.Content = &event.MessageEventContent{MsgType: event.MsgImage, Body: "test"}
	msg.Portal = &bridgev2.Portal{Portal: &database.Portal{PortalKey: networkid.PortalKey{ID: "route"}}}
	if _, err := cl.HandleMatrixMessage(context.Background(), msg); err == nil || backend.sends != 0 {
		t.Fatal("unsupported media called the transport")
	}
	msg.Content.MsgType = event.MsgText
	response, err := cl.HandleMatrixMessage(context.Background(), msg)
	if err != nil || backend.sends != 1 {
		t.Fatal("checked send failed", err)
	}
	mid, _ := messageID(account, backend.threads[0].Messages[0])
	if response.DB.ID != mid || !cl.pending[mid] {
		t.Fatal("outgoing echo identity differs")
	}
	backend.sendErr = true
	if _, err = cl.HandleMatrixMessage(context.Background(), msg); err == nil || backend.sends != 2 {
		t.Fatal("uncertain send was retried or reported successful")
	}
}

type testGuardDB struct{ *sql.DB }

func (d testGuardDB) Exec(ctx context.Context, query string, args ...any) (sql.Result, error) {
	return d.DB.ExecContext(ctx, query, args...)
}
func TestDurableSendGuard(t *testing.T) {
	name := filepath.Join(t.TempDir(), "guard.db")
	db, err := sql.Open("sqlite3", name)
	if err != nil {
		t.Fatal(err)
	}
	if _, err = db.Exec(`CREATE TABLE kv_store(bridge_id TEXT,key TEXT,value TEXT,PRIMARY KEY(bridge_id,key))`); err != nil {
		t.Fatal(err)
	}
	if err = claimSend(context.Background(), testGuardDB{db}, "fixture", "phone", "$event"); err != nil {
		t.Fatal(err)
	}
	db.Close()
	db, err = sql.Open("sqlite3", name)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if claimSend(context.Background(), testGuardDB{db}, "fixture", "phone", "$event") == nil {
		t.Fatal("replayed send accepted after restart")
	}
	if claimSend(context.Background(), testGuardDB{db}, "fixture", "phone", "") == nil {
		t.Fatal("missing event identity accepted")
	}
	if err = claimSend(context.Background(), testGuardDB{db}, "fixture", "phone", "$new-event"); err != nil {
		t.Fatal(err)
	}
}
func TestSingleProcessLock(t *testing.T) {
	dir := t.TempDir()
	first, err := lockProcess(dir)
	if err != nil {
		t.Fatal(err)
	}
	if second, err := lockProcess(dir); err == nil {
		second.Close()
		t.Fatal("second instance was allowed")
	}
	first.Close()
	second, err := lockProcess(dir)
	if err != nil {
		t.Fatal("lock was not released", err)
	}
	second.Close()
}
