# Layer 2: network

Owns the custom VPC; primary, Pod, Service, and Private Service Access ranges;
Private Google Access; bounded Flow Logs; and the explicitly opt-in Cloud NAT
experiment.

The configuration rejects non-canonical or overlapping CIDRs before apply. Its
capacity contract assumes at most six cluster nodes and 64 Pods per node. The
default `/16` Pod range therefore supports 512 node-sized Pod blocks. Layer 3
consumes the reserved `gke-lab-private-services` range rather than choosing one
implicitly.

The core profile has no Cloud Router or NAT. The `full`/`egress` profile enables
Cloud NAT with Google-managed addresses and is billable, so review its saved plan
and cost approval before applying it.

Run the local contract first:

```bash
make test-layer LAYER=2
```

Then create a read-only saved plan:

```bash
make plan-layer LAYER=2 PROFILE=core
```

After an approved apply, `make verify-layer LAYER=2 PROFILE=core` records the
VPC, subnet, reserved range, route, firewall, external-IP, default-network, and
NAT-negative evidence. An actual Private Google Access request and Flow Log
record require a workload source and are verified after the private cluster is
available.
