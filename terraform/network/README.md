# Layer 2: network

Owns the custom VPC, GKE subnet, Pod/Service secondary ranges, Private Google
Access, bounded Flow Logs, and the explicitly opt-in Cloud NAT experiment. Run
`tests/gates/network_test.go` before provisioning the platform layer.
