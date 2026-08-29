## Layer and outcome

- Layer(s):
- User/portfolio outcome:
- Cost/TTL impact:

## Local proof before push

- [ ] `make test-layer LAYER=<n>` passed for each changed layer.
- [ ] `make validate` passed in the Dev Container.
- [ ] Failure, recovery, and teardown paths were updated where behavior changed.
- [ ] Documentation, diagrams, version inventory, and evidence expectations agree.

## CI and live proof

- [ ] Required GitHub CI layer jobs passed.
- [ ] No pull-request job receives a GCP credential.
- [ ] If cloud behavior changed, the protected live gate and sanitized evidence passed.
- [ ] Public, paid, production, destructive, and final-delete approvals remain explicit.

## Rollback and cleanup

Describe rollback, reverse-order destroy impact, and the independent zero-resource check.
