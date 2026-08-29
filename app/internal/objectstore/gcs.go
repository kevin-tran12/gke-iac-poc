package objectstore

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"sync"
	"time"

	"cloud.google.com/go/storage"
	"github.com/kevin-tran12/gke-iac-poc/app/internal/jobs"
	"google.golang.org/api/googleapi"
)

var ErrNotFound = errors.New("result not found")
var ErrAlreadyExists = errors.New("result already exists")

type Results interface {
	Get(context.Context, string) (jobs.Result, error)
	Create(context.Context, jobs.Result) error
}

type GCSResults struct {
	bucket         *storage.BucketHandle
	readinessMu    sync.Mutex
	readinessUntil time.Time
	readinessErr   error
}

func New(client *storage.Client, bucket string) *GCSResults {
	return &GCSResults{bucket: client.Bucket(bucket)}
}

func objectName(jobID string) string { return "results/" + jobID + ".json" }

func (g *GCSResults) Check(ctx context.Context) error {
	g.readinessMu.Lock()
	defer g.readinessMu.Unlock()
	if time.Now().Before(g.readinessUntil) {
		return g.readinessErr
	}
	_, err := g.bucket.Attrs(ctx)
	if err != nil {
		g.readinessErr = fmt.Errorf("read result bucket metadata: %w", err)
	} else {
		g.readinessErr = nil
	}
	g.readinessUntil = time.Now().Add(30 * time.Second)
	return g.readinessErr
}

func (g *GCSResults) Get(ctx context.Context, jobID string) (jobs.Result, error) {
	r, err := g.bucket.Object(objectName(jobID)).NewReader(ctx)
	if errors.Is(err, storage.ErrObjectNotExist) {
		return jobs.Result{}, ErrNotFound
	}
	if err != nil {
		return jobs.Result{}, fmt.Errorf("open result: %w", err)
	}
	defer r.Close()
	b, err := io.ReadAll(io.LimitReader(r, 64*1024))
	if err != nil {
		return jobs.Result{}, fmt.Errorf("read result: %w", err)
	}
	var result jobs.Result
	if err := json.Unmarshal(b, &result); err != nil {
		return jobs.Result{}, fmt.Errorf("decode result: %w", err)
	}
	return result, nil
}

func (g *GCSResults) Create(ctx context.Context, result jobs.Result) error {
	b, err := json.Marshal(result)
	if err != nil {
		return fmt.Errorf("marshal result: %w", err)
	}
	obj := g.bucket.Object(objectName(result.JobID)).If(storage.Conditions{DoesNotExist: true})
	w := obj.NewWriter(ctx)
	w.ContentType = "application/json"
	w.CacheControl = "no-store"
	if _, err := w.Write(b); err != nil {
		_ = w.Close()
		return fmt.Errorf("write result: %w", err)
	}
	if err := w.Close(); err != nil {
		var apiErr *googleapi.Error
		if errors.As(err, &apiErr) && apiErr.Code == 412 {
			return ErrAlreadyExists
		}
		return fmt.Errorf("commit result: %w", err)
	}
	return nil
}
