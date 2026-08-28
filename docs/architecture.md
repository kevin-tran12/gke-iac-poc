# Architecture baseline

## Objective

Create a repeatable GKE demonstration that proves three different behaviors:

- external request routing and TLS termination;
- Service routing across healthy Pod endpoints; and
- workload HPA scaling, optionally followed by node-pool scaling.

This is functional validation, not a production hosting platform or performance
benchmark.

## Provisioning boundaries

```text
Terraform: cluster root
  -> APIs, IAM, VPC/subnet, Artifact Registry, GKE, optional cost controls
  -> outputs a reachable and authenticated Kubernetes API endpoint

Terraform: workloads root
  -> namespace, policies, Deployments, Services, HPA, load Jobs
  -> optional Gateway and Cloud Armor integration

Automated tests
  -> inspect durable Kubernetes state and make bounded HTTP requests
  -> always trigger Terraform teardown
```

The roots remain separate so the Kubernetes provider never has to initialize
before its cluster exists and so a failed workload deployment does not obscure
cluster teardown.

## Test workloads

| Workload | Purpose | Baseline image reference |
| --- | --- | --- |
| Request echo | Inspect safe test headers, path, host, and proxy metadata | `mendhak/http-https-echo` through a controlled registry, pinned by digest |
| GKE hello app | Observe multiple Pod hostnames through one Service | `us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0`, pinned by digest |
| HPA example | Produce bounded CPU pressure for HPA testing | `registry.k8s.io/hpa-example`, pinned by digest |

Third-party images must not be pulled directly by isolated nodes. The preferred
path is a same-region Artifact Registry remote or standard repository with narrow
reader access and cleanup policies. Cloud NAT is an explicit, billable fallback.

## Acceptance criteria

### Gateway, headers, and TLS

- An external client validates the certificate chain, hostname, and expiration.
- Plain HTTP redirects to HTTPS when HTTP is enabled.
- A unique, non-sensitive test header reaches the echo Pod as expected.
- The observed forwarding chain matches the selected GKE data-plane behavior.
- A Cloud Armor test, when enabled, proves blocked requests never reach the Pod.
- No credential, cookie, authorization header, environment variable, or real user
  payload appears in responses or logs.

### Service routing

- Every desired hello-app Pod becomes Ready.
- The Service has the expected ready endpoints.
- Automated requests using new connections observe at least two distinct Pod
  hostnames when two or more replicas are configured.
- Removing or failing one test Pod does not route requests to an unready endpoint.

### Autoscaling

- CPU requests and limits are explicit.
- A bounded load Job causes HPA desired and current replicas to increase within a
  defined timeout, without exceeding the configured maximum.
- Replicas become Ready and later return to the configured minimum.
- If cluster autoscaling is in scope, resource pressure makes an additional node
  necessary and the test separately proves the node count increased.
- Load generation terminates even when an assertion fails.

## Cost boundaries

- Use a zonal or Autopilot cluster only after confirming that the billing account's
  GKE management-fee credit is still available.
- Keep public Gateway, Cloud Armor, Cloud NAT, and load tests disabled by default.
- Cap HPA replicas and node-pool size with small, explicit values.
- Co-locate GKE and Artifact Registry and limit cached image versions.
- Estimate the selected machine, disk, load-balancer, Armor, NAT, logging, and data
  transfer costs before the first apply.
- Budgets and alerts are detection controls; automated teardown and hard scaling
  limits are the primary safeguards.

## Credible failure modes

| Failure | Expected detection and recovery |
| --- | --- |
| Private nodes cannot pull an image | Test fails on `ImagePullBackOff`; correct registry access or controlled egress, then retry |
| Terraform cannot reach the control plane | Workload root fails before mutation; correct endpoint reachability and short-lived authentication |
| HPA reports unknown metrics | Fail with a clear timeout; verify metrics availability and CPU requests |
| HPA Pods remain Pending | Report scheduler and autoscaler events; verify node cap and allocatable capacity |
| Gateway or certificate remains pending | Fail after a bounded timeout and destroy billable resources |
| Load Job or test runner fails | Job deadline and CI cleanup still stop load and destroy infrastructure |
| Terraform destroy is incomplete | Run the documented recovery procedure and verify no load balancer, NAT, IP, disk, node, or cluster remains |

## Decisions still required

- Google Cloud project and billing account.
- Region and zone.
- Standard versus Autopilot GKE.
- DNS-based or IP-based control-plane access for the Terraform runner.
- Internal-only versus public Gateway demonstration.
- Domain and certificate method for TLS.
- Local or remote Terraform state.
- Maximum cost and maximum environment lifetime per run.

