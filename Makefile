SHELL := /usr/bin/env bash
LAYER ?= 0
PROFILE ?= core
NAME ?=

.PHONY: validate security hooks layer test-layer provision-through release lab evidence teardown-runtime teardown-final verify-zero-cost diagrams

validate:
	bash ./scripts/validate.sh

security:
	bash ./scripts/ci/security-gates.sh

hooks:
	bash ./scripts/install-hooks.sh

layer:
	bash ./scripts/gates/run-layer.sh "$(LAYER)" "$(PROFILE)"

test-layer:
	bash ./scripts/ci/test-layer.sh "$(LAYER)"

provision-through:
	bash ./scripts/provision-through-layer.sh "$(LAYER)" "$(PROFILE)"

release:
	bash ./scripts/build-release.sh

lab:
	test -n "$(NAME)"
	bash ./scripts/run-lab.sh "$(NAME)"

evidence:
	bash ./scripts/collect-evidence.sh

teardown-runtime:
	bash ./scripts/teardown-runtime.sh

verify-zero-cost:
	bash ./scripts/verify-no-billable-resources.sh

teardown-final:
	bash ./scripts/teardown-final.sh

diagrams:
	bash ./scripts/render-diagrams.sh
