package config

import (
	"context"
	"fmt"

	secretmanager "cloud.google.com/go/secretmanager/apiv1"
	secretmanagerpb "cloud.google.com/go/secretmanager/apiv1/secretmanagerpb"
)

func AccessSecret(ctx context.Context, client *secretmanager.Client, resource string) (string, error) {
	if resource == "" {
		return "", fmt.Errorf("secret resource is required")
	}
	if len(resource) < len("/versions/latest") || resource[len(resource)-len("/versions/latest"):] != "/versions/latest" {
		resource += "/versions/latest"
	}
	result, err := client.AccessSecretVersion(ctx, &secretmanagerpb.AccessSecretVersionRequest{Name: resource})
	if err != nil {
		return "", fmt.Errorf("access secret: %w", err)
	}
	if result.Payload == nil || len(result.Payload.Data) == 0 {
		return "", fmt.Errorf("secret payload is empty")
	}
	return string(result.Payload.Data), nil
}
