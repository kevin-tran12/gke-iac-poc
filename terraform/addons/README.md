# Layer 5: cluster addons

Installs cert-manager after Gateway API is enabled and deploys a small
OpenTelemetry Collector. All five cert-manager component images and the collector
are supplied as Artifact Registry references with immutable digests. CI templates
the chart, validates CRDs, checks restricted Pod security, and proves telemetry
before workloads advance.
