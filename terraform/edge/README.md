# Layer 8: public edge

This root is approval-gated because reserving the address and creating the global
Gateway produce billable resources. It derives a temporary nip.io hostname,
obtains a Let's Encrypt certificate with cert-manager's Gateway solver, redirects
HTTP, attaches Cloud Armor, and routes only to previously tested Services.
