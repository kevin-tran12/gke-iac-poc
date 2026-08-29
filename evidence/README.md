# Evidence handling

`evidence/raw/` is ignored and contains short-lived, potentially sensitive command
output. Review it locally, remove credentials, headers, payloads, signed URLs,
unnecessary identities and local paths, then copy only curated artifacts into a
named sample directory. Every artifact must link to an acceptance criterion and
include commit, UTC time, profile and cleanup status.
