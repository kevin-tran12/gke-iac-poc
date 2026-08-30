SHELL := /usr/bin/env bash
LAYER ?= 0
PROFILE ?= core
NAME ?=

.PHONY: validate security hooks layer test-layer plan-layer apply-layer verify-layer destroy-layer full-lab-plan full-lab-apply provision-through release lab evidence teardown-runtime teardown-final verify-zero-cost diagrams

validate:
	bash ./scripts/validate.sh

security:
	bash ./scripts/ci/security-gates.sh

hooks:
	bash ./scripts/install-hooks.sh

layer:
	@printf 'make layer is plan-only; use make apply-layer and make verify-layer explicitly after reviewing the saved plan.\n'
	bash ./scripts/gates/plan-layer.sh "$(LAYER)" "$(PROFILE)"

test-layer:
	bash ./scripts/ci/test-layer.sh "$(LAYER)"

plan-layer:
	bash ./scripts/gates/plan-layer.sh "$(LAYER)" "$(PROFILE)"

apply-layer:
	bash ./scripts/gates/apply-layer.sh "$(LAYER)" "$(PROFILE)"

verify-layer:
	bash ./scripts/gates/verify-layer.sh "$(LAYER)" "$(PROFILE)"

destroy-layer:
	bash ./scripts/gates/destroy-layer.sh "$(LAYER)" "$(PROFILE)"

full-lab-plan:
	@printf 'A later layer cannot be planned before its live prerequisites exist. Plan, apply, verify, and merge one layer at a time.\n'; exit 2

full-lab-apply:
	@printf 'Bulk apply is disabled. Use make plan-layer, make apply-layer, and make verify-layer for each layer.\n'; exit 2

provision-through:
	@printf 'Bulk provision-through is disabled until every layer has an independently merged and verified PR.\n'; exit 2

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
