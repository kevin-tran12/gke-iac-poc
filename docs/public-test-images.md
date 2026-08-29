# Public test-image decision record

These images are diagnostics, not the product. They are mirrored into the lab's
Artifact Registry and Terraform accepts only immutable digest references.

| Image | Proof | Why it belongs | Security boundary |
| --- | --- | --- | --- |
| `mendhak/http-https-echo` | Request headers, path, host and client metadata | Demonstrates Gateway, TLS, forwarded headers and Cloud Armor | Baseline `test` namespace; no token; default-deny; digest mirror |
| `us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0` | Response hostname varies across three replicas | Demonstrates Service load balancing and rollout identity | Forced non-root UID; no token; digest mirror |
| `registry.k8s.io/hpa-example` | CPU rises per request | Reliably triggers HPA and cluster autoscaling | Legacy root/port-80 exception isolated to Baseline `test`; no identity or egress |

Source tags are discovery inputs only. `scripts/mirror-public-images.sh` pulls the
operator-approved source, pushes a temporary tag to the dedicated repository,
records the destination digest, and the tag is never passed to Terraform. Before
a live run, review the source repository, license, vulnerability scan, effective
user, architecture, and last update. A digest change is a reviewed dependency
change and must rerun layers 3, 5, and 6.

cert-manager is a pinned Helm-chart dependency rather than a portfolio image. All
five chart components are nevertheless mirrored by digest because private nodes
have no general egress in the core profile. Chart rendering and webhook health
are captured as layer-5 evidence. The public-edge profile explicitly enables
Cloud NAT for ACME traffic and removes it during reverse-order teardown.
