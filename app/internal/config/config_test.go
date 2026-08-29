package config

import "testing"

func setRequiredEnvironment(t *testing.T) {
	t.Helper()
	t.Setenv("GOOGLE_CLOUD_PROJECT", "project")
	t.Setenv("JOBS_TOPIC", "jobs")
	t.Setenv("JOBS_SUBSCRIPTION", "worker")
	t.Setenv("RESULTS_BUCKET", "results")
	t.Setenv("LAB_TOKEN_SECRET", "projects/project/secrets/token")
	t.Setenv("WORKER_SALT_SECRET", "projects/project/secrets/salt")
}

func TestLoadRequiresAllManagedDependencies(t *testing.T) {
	t.Setenv("GOOGLE_CLOUD_PROJECT", "project")
	if _, err := Load(); err == nil {
		t.Fatal("Load() succeeded with incomplete dependency configuration")
	}
}

func TestLoadRequiresCloudSQLUserWhenEnabled(t *testing.T) {
	setRequiredEnvironment(t)
	t.Setenv("CLOUD_SQL_CONNECTION_NAME", "project:region:instance")
	if _, err := Load(); err == nil {
		t.Fatal("Load() succeeded without CLOUD_SQL_USER")
	}
}

func TestLoadAcceptsCompleteCoreConfiguration(t *testing.T) {
	setRequiredEnvironment(t)
	if _, err := Load(); err != nil {
		t.Fatalf("Load() error = %v", err)
	}
}
