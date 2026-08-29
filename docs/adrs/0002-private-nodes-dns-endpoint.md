# ADR 0002: private nodes and DNS endpoint

**Decision:** nodes receive no public IP and the control plane exposes only GKE's
authenticated DNS endpoint. This removes master CIDR allowlist maintenance and
lets approved Google-managed delivery workers reach the cluster without a bastion.
