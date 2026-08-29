# Reliability and recovery

Pub/Sub provides at-least-once delivery. The worker makes that safe by creating a
deterministic GCS object with a generation precondition and acknowledging only
after the durable write and optional audit record succeed. Five failed delivery
attempts move a message to the DLQ. Retries are bounded by subscription policy.

Deployments use readiness/liveness probes, rolling updates, PDBs, topology spread,
resource limits, HPA caps, and a node-pool cap. Cloud Deploy verification prevents
automatic progression of an unhealthy release; production additionally requires
approval.

The recovery profile enables the GKE backup agent, backs up only the `test`
namespace without Secrets, restores Persistent Disk data, and validates the proof
file. Cloud SQL retains two short-lived backups and two days of transaction logs
only while the data profile exists.

Credible failure paths are implemented under `tests/labs`; corresponding runbooks
cover diagnosis, safe user behavior, recovery, and durable verification.
