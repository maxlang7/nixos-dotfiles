package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"syscall"
	"time"

	"maunium.net/go/mautrix/bridgev2/matrix/mxmain"
)

func main() {
	syscall.Umask(0077)
	if len(os.Args) == 2 && os.Args[1] == "--probe" {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		b, err := openBus()
		if err != nil {
			panic(err)
		}
		defer b.Close()
		var status map[string]any
		if err = b.JSON(ctx, "GetStatus", &status); err != nil {
			panic(err)
		}
		threads, err := b.Threads(ctx)
		if err != nil {
			panic(err)
		}
		contacts, err := b.Contacts(ctx)
		if err != nil {
			panic(err)
		}
		messages := 0
		for _, t := range threads {
			messages += len(t.Messages)
		}
		_ = json.NewEncoder(os.Stdout).Encode(map[string]any{"api_version": status["api_version"], "map_connected": status["map"], "threads": len(threads), "messages": messages, "contact_addresses": len(contacts)})
		return
	}
	c := &Connector{}
	m := &mxmain.BridgeMain{Name: "blueferry-beeper", Description: "BlueFerry text messaging bridge", Version: "0.1.0", Connector: c}
	m.PostInit = func() {
		home, err := os.UserHomeDir()
		if err == nil {
			processLock, err = lockProcess(filepath.Join(home, ".local/state/blueferry-beeper"))
		}
		if err != nil {
			fmt.Fprintln(os.Stderr, "BlueFerry bridge startup failed:", err)
			os.Exit(1)
		}
		if err := setBeeperMetadata(context.Background(), m.Config, c.Config.Owner); err != nil {
			c.br.Log.Warn().Msg("Could not confirm Beeper custom bridge metadata")
		}
	}
	m.PostStart = func() { go c.AutoLogin() }
	m.InitVersion("v0.1.0", "local", "")
	m.Run()
	fmt.Fprintln(os.Stderr, "BlueFerry bridge stopped")
}
