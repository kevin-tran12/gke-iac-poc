package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

type Config struct {
	ProjectID          string
	Port               string
	JobsTopic          string
	JobsSubscription   string
	ResultsBucket      string
	LabTokenSecret     string
	WorkerSaltSecret   string
	OTLPEndpoint       string
	CloudSQLConnection string
	CloudSQLUser       string
	CloudSQLDatabase   string
	ShutdownTimeout    time.Duration
	MaxPayloadBytes    int64
}

func Load() (Config, error) {
	cfg := Config{
		ProjectID:          os.Getenv("GOOGLE_CLOUD_PROJECT"),
		Port:               value("PORT", "8080"),
		JobsTopic:          os.Getenv("JOBS_TOPIC"),
		JobsSubscription:   os.Getenv("JOBS_SUBSCRIPTION"),
		ResultsBucket:      os.Getenv("RESULTS_BUCKET"),
		LabTokenSecret:     os.Getenv("LAB_TOKEN_SECRET"),
		WorkerSaltSecret:   os.Getenv("WORKER_SALT_SECRET"),
		OTLPEndpoint:       value("OTEL_EXPORTER_OTLP_ENDPOINT", "otel-collector.observability.svc.cluster.local:4317"),
		CloudSQLConnection: os.Getenv("CLOUD_SQL_CONNECTION_NAME"),
		CloudSQLUser:       os.Getenv("CLOUD_SQL_USER"),
		CloudSQLDatabase:   value("CLOUD_SQL_DATABASE", "gke_lab"),
		ShutdownTimeout:    15 * time.Second,
		MaxPayloadBytes:    4096,
	}

	if v := os.Getenv("MAX_PAYLOAD_BYTES"); v != "" {
		n, err := strconv.ParseInt(v, 10, 64)
		if err != nil || n < 1 || n > 65536 {
			return Config{}, fmt.Errorf("MAX_PAYLOAD_BYTES must be between 1 and 65536")
		}
		cfg.MaxPayloadBytes = n
	}
	if cfg.ProjectID == "" || cfg.JobsTopic == "" || cfg.JobsSubscription == "" || cfg.ResultsBucket == "" || cfg.LabTokenSecret == "" || cfg.WorkerSaltSecret == "" {
		return Config{}, fmt.Errorf("project, messaging, storage, and secret configuration is required")
	}
	if cfg.CloudSQLConnection != "" && cfg.CloudSQLUser == "" {
		return Config{}, fmt.Errorf("CLOUD_SQL_USER is required when Cloud SQL is enabled")
	}
	return cfg, nil
}

func value(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
