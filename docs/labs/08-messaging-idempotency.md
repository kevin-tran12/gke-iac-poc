# Lab 08: messaging idempotency

Publish the exact same versioned job twice. Observe at-least-once processing and
require exactly one `results/<job-id>.json` object with the expected digest. If SQL
is enabled, require one logical row and an incremented attempt counter. Ack only
after durable state; record DLQ behavior separately.
