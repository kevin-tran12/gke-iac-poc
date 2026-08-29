package main

import (
	"context"
	"log/slog"
	"os"
	"time"

	"github.com/kevin-tran12/gke-iac-poc/app/internal/config"
	"github.com/kevin-tran12/gke-iac-poc/app/internal/persistence"
)

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	cfg, err := config.Load()
	if err != nil {
		slog.Error("configuration failed", "error", err)
		os.Exit(1)
	}
	if cfg.CloudSQLConnection == "" || cfg.CloudSQLUser == "" {
		slog.Error("Cloud SQL migration configuration is required")
		os.Exit(1)
	}
	db, err := persistence.NewPostgres(ctx, cfg.CloudSQLConnection, cfg.CloudSQLUser, cfg.CloudSQLDatabase)
	if err != nil {
		slog.Error("Cloud SQL connection failed", "error", err)
		os.Exit(1)
	}
	defer db.Close()
	if err := db.Migrate(ctx); err != nil {
		slog.Error("migration failed", "error", err)
		os.Exit(1)
	}
	slog.Info("migration complete")
}
