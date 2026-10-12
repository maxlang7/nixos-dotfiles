package main

import (
	"errors"
	"os"
	"path/filepath"
	"syscall"
)

func lockProcess(directory string) (*os.File, error) {
	if err := os.MkdirAll(directory, 0700); err != nil {
		return nil, err
	}
	file, err := os.OpenFile(filepath.Join(directory, "process.lock"), os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return nil, err
	}
	if err = syscall.Flock(int(file.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		file.Close()
		return nil, errors.New("another BlueFerry Beeper bridge is already running")
	}
	return file, nil
}

// Keep the lock file reachable for the life of BridgeMain.Run, which exits via
// os.Exit. The OS releases the lock on exit, including crashes.
var processLock *os.File
