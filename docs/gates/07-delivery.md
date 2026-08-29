# Gate 07: application delivery

Cloud Build must pass tests, produce three images and an SBOM/provenance record.
Cloud Deploy renders the staging overlay by digest and verification submits a job,
waits for its durable GCS result, then repeats the message to prove idempotency.
Binary Authorization remains in audit/bootstrap mode until this passes.
