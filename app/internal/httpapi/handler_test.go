package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/kevin-tran12/gke-iac-poc/app/internal/jobs"
	"github.com/kevin-tran12/gke-iac-poc/app/internal/objectstore"
)

type fakePublisher struct {
	messages []jobs.Message
	err      error
}

func (f *fakePublisher) Publish(_ context.Context, message jobs.Message) error {
	f.messages = append(f.messages, message)
	return f.err
}

type fakeResults struct {
	result jobs.Result
	err    error
}

func (f fakeResults) Get(context.Context, string) (jobs.Result, error) { return f.result, f.err }
func (f fakeResults) Create(context.Context, jobs.Result) error        { return errors.New("not used") }

func TestSubmitRequiresBearerToken(t *testing.T) {
	h := New(&fakePublisher{}, fakeResults{}, "test-token", 4096, nil)
	r := httptest.NewRequest(http.MethodPost, "/v1/jobs", strings.NewReader(`{"payload":"safe"}`))
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", w.Code)
	}
}

func TestSubmitPublishesVersionedMessage(t *testing.T) {
	publisher := &fakePublisher{}
	h := New(publisher, fakeResults{}, "test-token", 4096, nil)
	r := httptest.NewRequest(http.MethodPost, "/v1/jobs", strings.NewReader(`{"payload":"safe"}`))
	r.Header.Set("Authorization", "Bearer test-token")
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if w.Code != http.StatusAccepted {
		t.Fatalf("status = %d, body = %s", w.Code, w.Body.String())
	}
	if len(publisher.messages) != 1 || publisher.messages[0].Version != jobs.MessageVersion {
		t.Fatalf("unexpected messages: %#v", publisher.messages)
	}
	if publisher.messages[0].Payload != "safe" {
		t.Fatalf("payload = %q", publisher.messages[0].Payload)
	}
}

func TestSubmitRejectsOversizedBody(t *testing.T) {
	publisher := &fakePublisher{}
	h := New(publisher, fakeResults{}, "test-token", 4, nil)
	r := httptest.NewRequest(http.MethodPost, "/v1/jobs", strings.NewReader(`{"payload":"too large"}`))
	r.Header.Set("Authorization", "Bearer test-token")
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", w.Code)
	}
	if len(publisher.messages) != 0 {
		t.Fatalf("published %d messages for rejected request", len(publisher.messages))
	}
}

func TestStatusReturnsQueuedWhenObjectMissing(t *testing.T) {
	h := New(&fakePublisher{}, fakeResults{err: objectstore.ErrNotFound}, "test-token", 4096, nil)
	r := httptest.NewRequest(http.MethodGet, "/v1/jobs/9d2ed04a-5865-4d1d-a503-8d5081a95a43", nil)
	r.Header.Set("Authorization", "Bearer test-token")
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if w.Code != http.StatusOK {
		t.Fatalf("status = %d", w.Code)
	}
	var response jobs.StatusResponse
	if err := json.NewDecoder(w.Body).Decode(&response); err != nil {
		t.Fatal(err)
	}
	if response.Status != "queued" {
		t.Fatalf("status = %q", response.Status)
	}
}

func TestReadinessFailsClosed(t *testing.T) {
	h := New(&fakePublisher{}, fakeResults{}, "test-token", 4096, func(context.Context) error { return errors.New("dependency down") })
	w := httptest.NewRecorder()
	h.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/readyz", nil))
	if w.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d", w.Code)
	}
}
