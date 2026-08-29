# Runbook: cluster access

Confirm the active project and approved WIF identity, then obtain credentials with
`gcloud container clusters get-credentials` using the cluster location. Test the
DNS endpoint with `kubectl auth can-i get pods --all-namespaces`. Do not enable an
IP endpoint as a shortcut; repair WIF, IAM, DNS, or the runner environment.
