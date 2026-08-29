# Runbook: Pods pending

Read scheduler events, requests, taints/tolerations, node selectors, quota, PVC
binding, Spot availability and autoscaler status. Do not raise caps blindly.
Determine whether the test intends HPA-only or node scaling, adjust the smallest
responsible constraint, and verify later scale-down.
