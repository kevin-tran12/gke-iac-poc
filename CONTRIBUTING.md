# Contributing

Changes are delivered one architectural layer at a time. A pull request that
adds or changes a layer must update its reusable CI workflow, gate tests,
documentation, evidence expectations, and cleanup procedure in the same change.

Run `make hooks` once, then `make test-layer LAYER=<n>` while building each
layer and `make validate` before every push. The version-controlled pre-push
hook runs the same shared scripts called by GitHub Actions. Run these commands
inside the Dev Container so Linux race detection and ShellCheck are available. Pull
requests are read-only with respect to Google Cloud. Live integration requires a
protected GitHub environment after merge or a maintainer-approved manual run.
