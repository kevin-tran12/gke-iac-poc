# Observability

Application logs are structured and carry job IDs but never payloads or secrets.
OpenTelemetry instruments HTTP requests and exports traces through the in-cluster
Collector. GKE sends platform logs and metrics to Cloud Logging, Cloud Monitoring,
Managed Prometheus, and Cloud Trace.

The dashboard set tracks HTTP request rate/error/latency, Pod readiness and
restarts, HPA replicas, unschedulable Pods, node utilization, Pub/Sub backlog age,
worker failures, Cloud Deploy rollout state, Gateway response codes, Cloud Armor
decisions, and SQL health when enabled.

Alerts cover unavailable API replicas, aged Pub/Sub backlog, failed rollout,
external health failure, approaching budget thresholds, and an environment older
than its TTL. Labels remain bounded; Flow Logs are sampled; raw debug output is
not retained. Every failure lab states the exact log, metric, event, or trace that
must detect it.
