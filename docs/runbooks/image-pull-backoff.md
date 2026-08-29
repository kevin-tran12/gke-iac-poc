# Runbook: ImagePullBackOff

Inspect Pod events and the exact digest. Confirm the image exists in the same-region
Artifact Registry and the node identity has only `artifactregistry.reader`.
Differentiate `NotFound`, permission denial, architecture mismatch, and missing
egress. Correct registry/IAM or explicitly run the NAT lab; never switch to
`latest` or add broad node credentials.
