# Runbook: Pub/Sub backlog

Check oldest unacked age, worker readiness, subscriber errors, Google API egress,
Secret/GCS access and DLQ growth. Bound retries and avoid adding replicas until the
dependency is healthy. Replay DLQ messages only after confirming idempotency and
record the final durable job count.
