# Layer 4: private GKE

Creates GKE Standard with private nodes, a DNS-only control-plane endpoint,
Dataplane V2, Cloud DNS, Workload Identity, managed Prometheus, a one-node
on-demand system pool, and a zero-to-three-node Spot application pool.

The zonal profile is the default. The regional profile changes only cluster
location and scheduling tests. Binary Authorization remains disabled until a
signed image has passed the delivery gate.

