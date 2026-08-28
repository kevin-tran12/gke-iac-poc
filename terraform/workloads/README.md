# Workload Terraform root

This root will manage Kubernetes-native resources after the GKE API is reachable:

- an isolated test namespace and security policies;
- echo, hello-app, and HPA Deployments and Services;
- an `autoscaling/v2` HorizontalPodAutoscaler;
- bounded load-generator Jobs; and
- optional Gateway API and Cloud Armor integration resources.

The Kubernetes provider is sufficient for the baseline. The Helm provider will be
added only if a concrete chart becomes necessary.

