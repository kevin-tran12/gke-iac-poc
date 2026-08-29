# Module boundaries

The first implementation keeps one concrete instance of each service in its
layer root so reviewers can trace it without abstraction. These directories
document the stable module boundaries. A boundary is promoted into a reusable
module only when a second environment or profile consumes the same interface;
this avoids speculative modules while preserving an explicit refactor path.
