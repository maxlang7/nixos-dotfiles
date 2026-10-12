package main

import (
	"context"
	"database/sql"
	"errors"
)

type guardExecutor interface {
	Exec(context.Context, string, ...any) (sql.Result, error)
}

func claimSend(ctx context.Context, db guardExecutor, bridgeID, account, eventID string) error {
	if eventID == "" {
		return errors.New("message has no Matrix event identity; refusing an unsafe send")
	}
	result, err := db.Exec(ctx, `INSERT INTO kv_store (bridge_id,key,value) VALUES ($1,$2,'attempted') ON CONFLICT (bridge_id,key) DO NOTHING`, bridgeID, "blueferry-send:"+digest(account+"\x00"+eventID))
	if err != nil {
		return errors.New("cannot persist the send guard; message was not submitted")
	}
	count, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if count != 1 {
		return errors.New("this message was already attempted. Check the phone before sending a new message")
	}
	return nil
}
