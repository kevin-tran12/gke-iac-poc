# ADR 0004: nip.io and cert-manager

**Decision:** use a static IP-derived nip.io name and Let's Encrypt HTTP-01 for the
core lab. It avoids purchasing a portfolio domain while still demonstrating TLS
lifecycle. The dependency is third-party and temporary; an owned-domain/Cloud DNS
profile is the documented fallback.
