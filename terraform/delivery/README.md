# Layer 7 and 9: delivery and enforcement

Cloud Deploy renders the Skaffold/Kustomize application, verifies staging, and
requires approval for production. This root also creates the KMS-backed Cloud
Build attestor and enforced Binary Authorization policy. The cluster root is
re-applied with `enable_binary_authorization=true` only after a signed image has
passed the staging gate.
