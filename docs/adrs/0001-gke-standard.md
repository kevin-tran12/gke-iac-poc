# ADR 0001: GKE Standard

**Decision:** use GKE Standard rather than Autopilot. Node-pool sizing, Spot
capacity, drains, upgrades and cluster autoscaling are explicit learning goals.
The cost and operational burden are bounded by a zonal default, one system node,
a zero-minimum Spot pool, TTL and automated teardown.
