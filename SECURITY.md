# Security policy

This is a disposable learning environment, not a production service. Report a
security issue privately through GitHub's security-advisory feature rather than
opening a public issue.

Never commit credentials, Terraform state, kubeconfigs, bearer tokens, raw lab
payloads, signed URLs, or unsanitized evidence. GitHub Actions authenticates to
Google Cloud through OIDC Workload Identity Federation; service-account keys are
not supported. The echo workload must receive synthetic headers only.

The lab token demonstrates workload-to-Secret-Manager access. It is not a
production identity design and must be rotated and destroyed with the lab.
