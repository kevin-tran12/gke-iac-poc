package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/kevin-tran12/gke-iac-poc/app/internal/auth"
	"github.com/kevin-tran12/gke-iac-poc/app/internal/jobs"
	"github.com/kevin-tran12/gke-iac-poc/app/internal/messaging"
	"github.com/kevin-tran12/gke-iac-poc/app/internal/objectstore"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/propagation"
)

type Handler struct {
	publisher  messaging.Publisher
	results    objectstore.Results
	token      string
	maxPayload int64
	ready      func(context.Context) error
}

func New(p messaging.Publisher, r objectstore.Results, token string, maxPayload int64, ready func(context.Context) error) http.Handler {
	h := &Handler{publisher: p, results: r, token: token, maxPayload: maxPayload, ready: ready}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", h.health)
	mux.HandleFunc("GET /readyz", h.readiness)
	mux.Handle("POST /v1/jobs", auth.Bearer(token, http.HandlerFunc(h.submit)))
	mux.Handle("GET /v1/jobs/{id}", auth.Bearer(token, http.HandlerFunc(h.status)))
	return requestLog(otelhttp.NewHandler(mux, "gke-lab-api"))
}

func (h *Handler) health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (h *Handler) readiness(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	if h.ready != nil && h.ready(ctx) != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "not_ready"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}

func (h *Handler) submit(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, h.maxPayload+128)
	var body struct {
		Payload string `json:"payload"`
	}
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&body); err != nil || strings.TrimSpace(body.Payload) == "" || int64(len([]byte(body.Payload))) > h.maxPayload {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_request"})
		return
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_request"})
		return
	}
	carrier := propagation.MapCarrier{}
	otel.GetTextMapPropagator().Inject(r.Context(), carrier)
	message := jobs.Message{
		Version: jobs.MessageVersion, JobID: uuid.NewString(), Payload: body.Payload,
		SubmittedAt: time.Now().UTC(), Traceparent: carrier.Get("traceparent"),
	}
	ctx, cancel := context.WithTimeout(r.Context(), 10*time.Second)
	defer cancel()
	if err := h.publisher.Publish(ctx, message); err != nil {
		slog.ErrorContext(ctx, "job publish failed", "job_id", message.JobID, "error", err)
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "dependency_unavailable"})
		return
	}
	writeJSON(w, http.StatusAccepted, jobs.StatusResponse{JobID: message.JobID, Status: "queued"})
}

func (h *Handler) status(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if _, err := uuid.Parse(id); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_job_id"})
		return
	}
	result, err := h.results.Get(r.Context(), id)
	if errors.Is(err, objectstore.ErrNotFound) {
		writeJSON(w, http.StatusOK, jobs.StatusResponse{JobID: id, Status: "queued"})
		return
	}
	if err != nil {
		slog.ErrorContext(r.Context(), "result read failed", "job_id", id, "error", err)
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "dependency_unavailable"})
		return
	}
	writeJSON(w, http.StatusOK, jobs.StatusResponse{JobID: id, Status: result.Status, Result: &result})
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func requestLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/healthz" && r.URL.Path != "/readyz" {
			slog.InfoContext(r.Context(), "request", "method", r.Method, "path", r.URL.Path)
		}
		next.ServeHTTP(w, r)
	})
}
