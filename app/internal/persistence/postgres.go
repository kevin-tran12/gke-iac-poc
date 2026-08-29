package persistence

import (
	"context"
	"database/sql"
	"fmt"
	"net"

	"cloud.google.com/go/cloudsqlconn"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/stdlib"
	"github.com/kevin-tran12/gke-iac-poc/app/internal/jobs"
)

type Recorder interface {
	Record(context.Context, jobs.Result, string) error
	Close() error
}

type Noop struct{}

func (Noop) Record(context.Context, jobs.Result, string) error { return nil }
func (Noop) Close() error                                      { return nil }

type Postgres struct {
	db     *sql.DB
	dialer *cloudsqlconn.Dialer
}

const schema = `
CREATE TABLE IF NOT EXISTS jobs (
  id UUID PRIMARY KEY,
  status TEXT NOT NULL CHECK (status IN ('queued', 'processing', 'completed', 'failed')),
  payload_hash TEXT,
  result_object TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  attempt_count INTEGER NOT NULL DEFAULT 1,
  error_code TEXT
);
CREATE INDEX IF NOT EXISTS jobs_status_updated_idx ON jobs (status, updated_at);`

func NewPostgres(ctx context.Context, instance, user, database string) (*Postgres, error) {
	dialer, err := cloudsqlconn.NewDialer(ctx, cloudsqlconn.WithIAMAuthN())
	if err != nil {
		return nil, fmt.Errorf("create Cloud SQL dialer: %w", err)
	}
	cfg, err := pgx.ParseConfig(fmt.Sprintf("user=%s dbname=%s sslmode=disable", user, database))
	if err != nil {
		_ = dialer.Close()
		return nil, fmt.Errorf("parse PostgreSQL config: %w", err)
	}
	cfg.DialFunc = func(ctx context.Context, _, _ string) (net.Conn, error) {
		return dialer.Dial(ctx, instance, cloudsqlconn.WithPrivateIP())
	}
	db := sql.OpenDB(stdlib.GetConnector(*cfg))
	if err := db.PingContext(ctx); err != nil {
		_ = db.Close()
		_ = dialer.Close()
		return nil, fmt.Errorf("ping Cloud SQL: %w", err)
	}
	return &Postgres{db: db, dialer: dialer}, nil
}

func (p *Postgres) Record(ctx context.Context, result jobs.Result, object string) error {
	_, err := p.db.ExecContext(ctx, `
		INSERT INTO jobs (id, status, result_object, updated_at)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status,
		result_object = EXCLUDED.result_object, updated_at = EXCLUDED.updated_at,
		attempt_count = jobs.attempt_count + 1`, result.JobID, result.Status, object, result.CompletedAt)
	if err != nil {
		return fmt.Errorf("record job: %w", err)
	}
	return nil
}

func (p *Postgres) Migrate(ctx context.Context) error {
	if _, err := p.db.ExecContext(ctx, schema); err != nil {
		return fmt.Errorf("apply schema: %w", err)
	}
	return nil
}

func (p *Postgres) Close() error { _ = p.db.Close(); return p.dialer.Close() }
