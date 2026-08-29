# Lab 04: cluster autoscaling

Record node count and allocatable capacity. Create bounded resource pressure that
cannot fit the current pool, observe Pending scheduler events, then prove the Spot
pool adds a node and Pods become Ready. Remove load and prove scale-down. Keep this
evidence separate from HPA evidence.
