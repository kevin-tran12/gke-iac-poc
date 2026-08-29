# Interview talking points

- I split Terraform by dependency and failure boundary so GKE-dependent providers
  never initialize before the cluster and public/costly services remain gated.
- I used GitHub WIF and GKE Workload Identity to remove long-lived keys from both
  delivery and runtime paths.
- I treated Pub/Sub as at-least-once and made the durable write idempotent rather
  than claiming exactly-once processing.
- I separated HPA from cluster autoscaler testing because they answer different
  capacity questions.
- I introduced Binary Authorization in two steps—signed-image proof, then
  enforcement—to avoid locking out the bootstrap deployment.
- I made teardown a tested product feature because an ephemeral lab that leaks a
  load balancer, NAT, SQL instance, or disk is operationally incomplete.
