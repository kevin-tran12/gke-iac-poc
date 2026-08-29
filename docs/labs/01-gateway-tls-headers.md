# Lab 01: Gateway, TLS and headers

After gate 8, validate DNS, certificate chain/name/expiry and HTTP redirect. Send
only a synthetic `X-Lab-Trace` header to `/echo`; compare host, path, forwarding
chain and client-IP behavior with Gateway documentation. Send an SQLi-shaped query
and prove a 403 plus Cloud Armor log and no backend request. Cleanup: edge root.
