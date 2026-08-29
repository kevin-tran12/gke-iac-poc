# Sample incident: NetworkPolicy blocked Google APIs

A temporary failure policy selected the worker and removed its effective Google
API egress. Pub/Sub backlog age increased and workers logged bounded dependency
errors; the API remained healthy but jobs stayed queued. Removing the policy
restored processing and the duplicate-safe GCS contract produced one result per
job. Corrective control: policy contract tests for DNS, metadata and restricted
Google API ranges before workload promotion.
