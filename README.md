# GKE Infrastructure-as-Code Proof of Concept

This repository is a standalone, disposable proof of concept for validating a
Google Kubernetes Engine cluster and its networking and autoscaling behavior.
Terraform will own all cloud and Kubernetes resources; no manual `kubectl apply`
steps will be required.

## Demonstrations

1. Gateway or Ingress routing, forwarded headers, and client-side TLS validation
   with a request-echo workload.
2. Kubernetes Service routing across multiple ready Pods with Google's GKE
   `hello-app` sample.
3. Horizontal Pod Autoscaler behavior under bounded CPU load, with a separate
   assertion for GKE node autoscaling when that scenario is enabled.

## Safety principles

- Keep the environment ephemeral and make teardown part of every automated run.
- Disable public load balancing, Cloud Armor, Cloud NAT, and load generation by
  default; each must be an explicit opt-in.
- Pin providers in Terraform and container images by digest.
- Never send credentials, cookies, tokens, or real user data to the echo service.
- Set resource requests, limits, replica caps, node caps, and test timeouts.
- Use short-lived Google credentials and least-privilege service accounts.
- Treat `kubectl` as an observation and verification tool, not a resource manager.

## Repository layout

```text
docs/                  Architecture, decisions, costs, and runbooks
terraform/cluster/     Google Cloud, networking, registry, and GKE resources
terraform/workloads/   Kubernetes workloads and optional Gateway resources
tests/                 Automated end-to-end verification
```

## Status

The repository structure and design baseline are established. No Google Cloud
resources or Terraform configuration have been created yet. Before implementation,
the project, region, cluster mode, control-plane access, DNS/TLS approach, state
backend, and maximum acceptable test cost must be selected.

