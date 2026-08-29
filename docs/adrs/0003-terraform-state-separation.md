# ADR 0003: state by failure boundary

**Decision:** keep bootstrap, network, platform, cluster, addons, workloads,
delivery, edge and recovery state separate. This adds initialization work but
prevents provider bootstrapping cycles and allows public/paid layers to be removed
without destabilizing the private platform.
