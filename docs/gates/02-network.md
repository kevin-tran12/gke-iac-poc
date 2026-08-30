# Gate 02: network

Verify the custom-mode regional VPC and these explicit, non-overlapping RFC1918
ranges:

- Node primary range: `10.10.0.0/20`.
- Pod secondary range: `10.20.0.0/16`.
- Service secondary range: `10.30.0.0/20`.
- Private Service Access range: `10.40.0.0/16`.

Terraform rejects overlap, non-canonical CIDRs, public ranges, or address spaces
that cannot support the declared six-node/64-Pod-per-node capacity contract.
Private Google Access must be enabled. Flow Logs use ten-minute aggregation,
10% sampling, and no metadata to bound cost and metadata exposure.

The live gate proves there is no default VPC, broad `0.0.0.0/0` ingress rule,
instance next-hop route, or VM external IP attached to this VPC. A core-profile
verification also proves the NAT router is absent. The paid `full`/`egress`
profile instead captures the router, NAT configuration, error-only logging, and
allocated-IP evidence.

The default internet-gateway route is intentionally retained: Private Google
Access uses Google networking and does not require deleting that route. Once a
private cluster exists, a later live test must prove Google API access and emit a
sample Flow Log from a controlled Pod; Layer 2 alone has no traffic source.
