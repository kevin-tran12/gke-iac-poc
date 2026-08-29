package messaging

import (
	"context"
	"encoding/json"
	"fmt"

	"cloud.google.com/go/pubsub/v2"
	"github.com/kevin-tran12/gke-iac-poc/app/internal/jobs"
)

type Publisher interface {
	Publish(context.Context, jobs.Message) error
}

type PubSubPublisher struct {
	publisher *pubsub.Publisher
}

func NewPublisher(client *pubsub.Client, topic string) *PubSubPublisher {
	return &PubSubPublisher{publisher: client.Publisher(topic)}
}

func (p *PubSubPublisher) Publish(ctx context.Context, message jobs.Message) error {
	b, err := json.Marshal(message)
	if err != nil {
		return fmt.Errorf("marshal job: %w", err)
	}
	result := p.publisher.Publish(ctx, &pubsub.Message{
		Data: b,
		Attributes: map[string]string{
			"schema_version": fmt.Sprint(message.Version),
			"job_id":         message.JobID,
		},
	})
	if _, err := result.Get(ctx); err != nil {
		return fmt.Errorf("publish job: %w", err)
	}
	return nil
}

func (p *PubSubPublisher) Stop() { p.publisher.Stop() }
