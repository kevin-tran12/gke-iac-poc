package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"cloud.google.com/go/pubsub/v2"
	secretmanager "cloud.google.com/go/secretmanager/apiv1"
	"cloud.google.com/go/storage"
	"github.com/kevin-tran12/gke-iac-poc/app/internal/config"
	"github.com/kevin-tran12/gke-iac-poc/app/internal/jobs"
	"github.com/kevin-tran12/gke-iac-poc/app/internal/objectstore"
	"github.com/kevin-tran12/gke-iac-poc/app/internal/persistence"
	"github.com/kevin-tran12/gke-iac-poc/app/internal/telemetry"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/propagation"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	cfg, err := config.Load()
	if err != nil {
		slog.Error("configuration failed", "error", err)
		os.Exit(1)
	}
	shutdownTrace, err := telemetry.Setup(ctx, "gke-lab-worker", cfg.OTLPEndpoint)
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
	salt, err := config.AccessSecret(ctx, secretClient, cfg.WorkerSaltSecret)
	if err != nil {
		slog.Error("salt access failed", "error", err)
		os.Exit(1)
	}

	storageClient, err := storage.NewClient(ctx)
	if err != nil {
		slog.Error("storage client failed", "error", err)
		os.Exit(1)
	}
	defer storageClient.Close()
	results := objectstore.New(storageClient, cfg.ResultsBucket)

	var recorder persistence.Recorder = persistence.Noop{}
	if cfg.CloudSQLConnection != "" {
		recorder, err = persistence.NewPostgres(ctx, cfg.CloudSQLConnection, cfg.CloudSQLUser, cfg.CloudSQLDatabase)
		if err != nil {
			slog.Error("Cloud SQL connection failed", "error", err)
			os.Exit(1)
		}
	}
	defer recorder.Close()

	client, err := pubsub.NewClient(ctx, cfg.ProjectID)
	if err != nil {
		slog.Error("pubsub client failed", "error", err)
		os.Exit(1)
	}
	defer client.Close()
	subscriber := client.Subscriber(cfg.JobsSubscription)
	subscriber.ReceiveSettings.MaxOutstandingMessages = 10
	subscriber.ReceiveSettings.NumGoroutines = 1

	err = subscriber.Receive(ctx, func(messageCtx context.Context, message *pubsub.Message) {
		var job jobs.Message
		if err := json.Unmarshal(message.Data, &job); err != nil || job.Version != jobs.MessageVersion || job.JobID == "" {
			slog.ErrorContext(messageCtx, "invalid job message", "message_id", message.ID)
			message.Nack()
			return
		}
		messageCtx = otel.GetTextMapPropagator().Extract(messageCtx, propagation.MapCarrier{"traceparent": job.Traceparent})
		messageCtx, span := otel.Tracer("gke-lab-worker").Start(messageCtx, "process job")
		defer span.End()
		span.SetAttributes(
			attribute.String("messaging.system", "gcp_pubsub"),
			attribute.String("job.id", job.JobID),
		)
		digest := sha256.Sum256([]byte(job.Payload + salt))
		result := jobs.Result{Version: 1, JobID: job.JobID, Status: "completed", Digest: hex.EncodeToString(digest[:]), CompletedAt: time.Now().UTC()}
		if err := results.Create(messageCtx, result); err != nil && !errors.Is(err, objectstore.ErrAlreadyExists) {
			slog.ErrorContext(messageCtx, "result write failed", "job_id", job.JobID, "error", err)
			message.Nack()
			return
		}
		if err := recorder.Record(messageCtx, result, "results/"+job.JobID+".json"); err != nil {
			slog.ErrorContext(messageCtx, "audit record failed", "job_id", job.JobID, "error", err)
			message.Nack()
			return
		}
		message.Ack()
		slog.InfoContext(messageCtx, "job completed", "job_id", job.JobID)
	})
	if err != nil && ctx.Err() == nil {
		slog.Error("subscriber stopped", "error", err)
		os.Exit(1)
	}
}
