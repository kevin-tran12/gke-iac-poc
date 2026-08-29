package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"cloud.google.com/go/pubsub/v2"
	secretmanager "cloud.google.com/go/secretmanager/apiv1"
	"cloud.google.com/go/storage"
	"github.com/kevin-tran12/gke-iac-poc/app/internal/config"
	"github.com/kevin-tran12/gke-iac-poc/app/internal/httpapi"
	"github.com/kevin-tran12/gke-iac-poc/app/internal/messaging"
	"github.com/kevin-tran12/gke-iac-poc/app/internal/objectstore"
	"github.com/kevin-tran12/gke-iac-poc/app/internal/telemetry"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	cfg, err := config.Load()
	if err != nil {
		slog.Error("configuration failed", "error", err)
		os.Exit(1)
	}
	shutdownTrace, err := telemetry.Setup(ctx, "gke-lab-api", cfg.OTLPEndpoint)
	if err != nil {
		slog.Error("telemetry setup failed", "error", err)
		os.Exit(1)
	}
	defer shutdownTrace(context.Background())

	secretClient, err := secretmanager.NewClient(ctx)
	if err != nil {
		slog.Error("secret client failed", "error", err)
		os.Exit(1)
	}
	defer secretClient.Close()
	token, err := config.AccessSecret(ctx, secretClient, cfg.LabTokenSecret)
	if err != nil {
		slog.Error("token access failed", "error", err)
		os.Exit(1)
	}

	pubsubClient, err := pubsub.NewClient(ctx, cfg.ProjectID)
	if err != nil {
		slog.Error("pubsub client failed", "error", err)
		os.Exit(1)
	}
	defer pubsubClient.Close()
	publisher := messaging.NewPublisher(pubsubClient, cfg.JobsTopic)
	defer publisher.Stop()

	storageClient, err := storage.NewClient(ctx)
	if err != nil {
		slog.Error("storage client failed", "error", err)
		os.Exit(1)
	}
	defer storageClient.Close()
	results := objectstore.New(storageClient, cfg.ResultsBucket)

	server := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           httpapi.New(publisher, results, token, cfg.MaxPayloadBytes, results.Check),
		ReadHeaderTimeout: 5 * cfg.ShutdownTimeout / 15,
		ReadTimeout:       10 * cfg.ShutdownTimeout / 15,
		WriteTimeout:      10 * cfg.ShutdownTimeout / 15,
		IdleTimeout:       60 * cfg.ShutdownTimeout / 15,
	}
	go func() {
		<-ctx.Done()
		shutdown, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
		defer cancel()
		_ = server.Shutdown(shutdown)
	}()
	slog.Info("api listening", "port", cfg.Port)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		slog.Error("server failed", "error", err)
		os.Exit(1)
	}
}
