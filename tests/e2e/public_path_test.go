package e2e

import (
	"bytes"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"testing"
	"time"
)

func liveClient(t *testing.T) (*http.Client, string, string) {
	t.Helper()
	base := strings.TrimRight(os.Getenv("LAB_BASE_URL"), "/")
	token := os.Getenv("LAB_TOKEN")
	if base == "" || token == "" {
		t.Skip("LAB_BASE_URL and LAB_TOKEN are required for live E2E")
	}
	return &http.Client{Timeout: 10 * time.Second}, base, token
}

func TestTLSAndHealth(t *testing.T) {
	client, base, _ := liveClient(t)
	response, err := client.Get(base + "/hello")
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		t.Fatalf("status = %d", response.StatusCode)
	}
	if response.TLS == nil || response.TLS.Version < tls.VersionTLS12 {
		t.Fatal("validated TLS 1.2+ connection required")
	}
}

func TestDurableJobJourney(t *testing.T) {
	client, base, token := liveClient(t)
	request, _ := http.NewRequest(http.MethodPost, base+"/api/v1/jobs", bytes.NewBufferString(`{"payload":"synthetic-ci-payload"}`))
	request.Header.Set("Authorization", "Bearer "+token)
	request.Header.Set("Content-Type", "application/json")
	response, err := client.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusAccepted {
		body, _ := io.ReadAll(response.Body)
		t.Fatalf("status = %d: %s", response.StatusCode, body)
	}
	var submitted struct {
		JobID string `json:"job_id"`
	}
	if err := json.NewDecoder(response.Body).Decode(&submitted); err != nil {
		t.Fatal(err)
	}

	deadline := time.Now().Add(90 * time.Second)
	for time.Now().Before(deadline) {
		request, _ = http.NewRequest(http.MethodGet, fmt.Sprintf("%s/api/v1/jobs/%s", base, submitted.JobID), nil)
		request.Header.Set("Authorization", "Bearer "+token)
		response, err = client.Do(request)
		if err != nil {
			t.Fatal(err)
		}
		var status struct {
			Status string `json:"status"`
		}
		err = json.NewDecoder(response.Body).Decode(&status)
		response.Body.Close()
		if err != nil {
			t.Fatal(err)
		}
		if status.Status == "completed" {
			return
		}
		time.Sleep(2 * time.Second)
	}
	t.Fatal("job did not reach a durable completed state")
}
