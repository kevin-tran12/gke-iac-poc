# Lab 02: Service load balancing

Start with three Ready hello Pods and record EndpointSlices. Make fresh-connection
requests until at least two hostnames are observed. Fail one Pod's readiness and
prove its endpoint becomes unready and receives no traffic. Reconcile the
Deployment and verify all replicas/Endpoints return.
