SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

# Tools
TF ?= terraform
PRECOMMIT ?= pre-commit
TFLINT ?= tflint

# Pre-commit configs (keep both at repo root)
PRECOMMIT_LOCAL ?= .pre-commit-config.yaml
PRECOMMIT_CI ?= .pre-commit-config-ci.yaml

# Stack selection (root module folder)
# Example: make validate STACK=live/global/00-bootstrap-state
STACK ?=

# Optional: space-separated -var-file paths (repo-root relative)
# Example: make plan STACK=live/dev/10-vpc VAR_FILES="live/dev/dev.auto.tfvars live/dev/common.tfvars"
VAR_FILES ?=

# Extra args
PLAN_ARGS ?=
APPLY_ARGS ?=

# Safety: block local apply by default (CI-only deployments)
ALLOW_LOCAL_APPLY ?= 0

# Marker used to discover stacks
STACK_MARKER := backend.hcl.example
STACKS := $(shell find live -name $(STACK_MARKER) -print 2>/dev/null | sed 's#/$(STACK_MARKER)$$##' | sort)

TF_VARFILE_ARGS := $(foreach f,$(VAR_FILES),-var-file=$(abspath $(f)))

define require_stack
	@if [[ -z "$(STACK)" ]]; then \
	  echo "ERROR: STACK is required (e.g. STACK=live/dev/10-vpc)"; \
	  exit 2; \
	fi
endef

help:
	@echo ""
	@echo "Common:"
	@echo "  make hooks                 Install git pre-commit hooks (local dev)"
	@echo "  make check                 Run pre-commit using $(PRECOMMIT_LOCAL)"
	@echo "  make check-ci              Run pre-commit using $(PRECOMMIT_CI)"
	@echo ""
	@echo "Terraform (explicit, per-stack):"
	@echo "  make fmt [STACK=...]        terraform fmt (stack or whole repo)"
	@echo "  make validate STACK=...     terraform init -backend=false + validate"
	@echo "  make plan STACK=...         terraform plan (requires backend.hcl present locally)"
	@echo "  make apply STACK=...        BLOCKED unless ALLOW_LOCAL_APPLY=1"
	@echo ""
	@echo "Utilities:"
	@echo "  make list-stacks            List detected stack folders under live/"
	@echo "  make clean STACK=...        Remove local artifacts for that stack"
	@echo ""
	@echo "Examples:"
	@echo "  make hooks"
	@echo "  make check"
	@echo "  make validate STACK=live/global/00-bootstrap-state"
	@echo "  make plan STACK=live/dev/10-vpc VAR_FILES='live/dev/dev.auto.tfvars'"
	@echo ""

hooks:
	@$(PRECOMMIT) --version >/dev/null 2>&1 || (echo "pre-commit not found. Install: pip install pre-commit" && exit 2)
	@$(PRECOMMIT) install
	@echo "Installed pre-commit hooks."

check:
	@$(PRECOMMIT) run --all-files --config $(PRECOMMIT_LOCAL)

check-ci:
	@$(PRECOMMIT) run --all-files --config $(PRECOMMIT_CI)

list-stacks:
	@if [[ -z "$(STACKS)" ]]; then \
	  echo "No stacks found under live/ (expected marker: $(STACK_MARKER))"; \
	  exit 0; \
	fi
	@printf "%s\n" $(STACKS)

fmt:
	@if [[ -n "$(STACK)" ]]; then \
	  $(TF) -chdir="$(STACK)" fmt -recursive ; \
	else \
	  $(TF) fmt -recursive ; \
	fi

validate:
	$(call require_stack)
	@echo "==> validate $(STACK) (init -backend=false)"
	@$(TF) -chdir="$(STACK)" init -backend=false -upgrade >/dev/null
	@$(TF) -chdir="$(STACK)" validate

plan:
	$(call require_stack)
	@echo "==> plan $(STACK)"
	@if [[ ! -f "$(STACK)/backend.hcl" ]]; then \
	  echo "ERROR: $(STACK)/backend.hcl not found (local plan requires it)."; \
	  echo "       Create it from backend.hcl.example and DO NOT commit backend.hcl."; \
	  exit 2; \
	fi
	@$(TF) -chdir="$(STACK)" init -reconfigure -backend-config=backend.hcl
	@$(TF) -chdir="$(STACK)" plan -input=false -lock-timeout=5m -out=tfplan $(TF_VARFILE_ARGS) $(PLAN_ARGS)
	@$(TF) -chdir="$(STACK)" show -no-color tfplan > tfplan.txt
	@echo "Plan saved: $(STACK)/tfplan and $(STACK)/tfplan.txt"

apply:
	$(call require_stack)
	@if [[ "$(ALLOW_LOCAL_APPLY)" != "1" ]]; then \
	  echo "BLOCKED: local apply is disabled (CI-only deployments)."; \
	  echo "If you must apply locally: make apply STACK=... ALLOW_LOCAL_APPLY=1"; \
	  exit 2; \
	fi
	@if [[ ! -f "$(STACK)/backend.hcl" ]]; then \
	  echo "ERROR: $(STACK)/backend.hcl not found."; \
	  exit 2; \
	fi
	@$(TF) -chdir="$(STACK)" init -reconfigure -backend-config=backend.hcl
	@$(TF) -chdir="$(STACK)" apply -input=false -auto-approve $(APPLY_ARGS)

clean:
	$(call require_stack)
	@rm -rf "$(STACK)/.terraform" "$(STACK)/tfplan" "$(STACK)/tfplan.txt" "$(STACK)/backend.hcl"
	@echo "Cleaned local artifacts in $(STACK)"
