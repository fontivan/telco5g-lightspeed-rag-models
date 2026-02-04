# SPDX-License-Identifier: Apache-2.0
# Root Makefile for Lightspeed Telco RAG Models
# Provides targets to run RAG image generation across all operator subprojects

SHELL := /usr/bin/env bash

# Get the root directory for make
ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

# Get absolute path to make executable for recursive calls
# This helps avoid reexec issues in containers with old make versions
MAKE_ABS := $(shell command -v $(MAKE) 2>/dev/null || which $(MAKE) 2>/dev/null || echo $(MAKE))

# venv python integration derived from https://venthur.de/2021-03-31-python-makefiles.html
# Host python is used to setup venv
PY ?= python3
VENV := $(ROOT_DIR)/venv
BIN := $(VENV)/bin

# List of operator subprojects
SUBPROJECTS := platform-resource-usage

# RAG configuration variables (can be overridden via command line)
# TARGET_PLATFORM defaults to linux, can be overridden (e.g., linux, windows)
TARGET_PLATFORM ?= linux

# TARGET_ARCH defaults to "multi" (builds both amd64 and arm64), can be overridden (e.g., amd64, arm64, multi, x86_64, aarch64)
# Normalize architecture names to podman-style (x86_64 -> amd64, aarch64 -> arm64)
ifndef TARGET_ARCH
  TARGET_ARCH := multi
endif
TARGET_ARCH := $(shell echo "$(TARGET_ARCH)" | sed 's/x86_64/amd64/; s/aarch64/arm64/')

# CONTAINER_ENGINE defaults to podman, can be overridden (e.g., podman, docker)
CONTAINER_ENGINE ?= podman

# Default target
.PHONY: all
all: rag-help ## Display help information

# RAG targets that run across all subprojects
.PHONY: rag-build-all
rag-build-all: ## Build RAG images for all operator subprojects
	@echo "Building RAG images for all subprojects..."
	@for subproject in $(SUBPROJECTS); do \
		echo ""; \
		echo "=== Building $$subproject ==="; \
		$(MAKE_ABS) -C $$subproject RAG_IMAGE_USERNAME=$(RAG_IMAGE_USERNAME) TARGET_PLATFORM=$(TARGET_PLATFORM) TARGET_ARCH=$(TARGET_ARCH) CONTAINER_ENGINE=$(CONTAINER_ENGINE) rag-build || exit 1; \
	done
	@echo ""
	@echo "All RAG images built successfully."

.PHONY: rag-load-all
rag-load-all: ## Load RAG images for all operator subprojects
	@echo "Loading RAG images for all subprojects..."
	@for subproject in $(SUBPROJECTS); do \
		echo ""; \
		echo "=== Loading $$subproject ==="; \
		$(MAKE_ABS) -C $$subproject RAG_IMAGE_USERNAME=$(RAG_IMAGE_USERNAME) TARGET_PLATFORM=$(TARGET_PLATFORM) TARGET_ARCH=$(TARGET_ARCH) CONTAINER_ENGINE=$(CONTAINER_ENGINE) rag-load || exit 1; \
	done
	@echo ""
	@echo "All RAG images loaded successfully."

.PHONY: rag-tag-all
rag-tag-all: ## Tag RAG images for all operator subprojects
	@echo "Tagging RAG images for all subprojects..."
	@for subproject in $(SUBPROJECTS); do \
		echo ""; \
		echo "=== Tagging $$subproject ==="; \
		$(MAKE_ABS) -C $$subproject RAG_IMAGE_USERNAME=$(RAG_IMAGE_USERNAME) TARGET_PLATFORM=$(TARGET_PLATFORM) TARGET_ARCH=$(TARGET_ARCH) CONTAINER_ENGINE=$(CONTAINER_ENGINE) rag-tag || exit 1; \
	done
	@echo ""
	@echo "All RAG images tagged successfully."

.PHONY: rag-push-all
rag-push-all: ## Push RAG images for all operator subprojects
	@echo "Pushing RAG images for all subprojects..."
	@for subproject in $(SUBPROJECTS); do \
		echo ""; \
		echo "=== Pushing $$subproject ==="; \
		$(MAKE_ABS) -C $$subproject RAG_IMAGE_USERNAME=$(RAG_IMAGE_USERNAME) TARGET_PLATFORM=$(TARGET_PLATFORM) TARGET_ARCH=$(TARGET_ARCH) CONTAINER_ENGINE=$(CONTAINER_ENGINE) rag-push || exit 1; \
	done
	@echo ""
	@echo "All RAG images pushed successfully."

.PHONY: rag-all-all
rag-all-all: ## Complete workflow (build, load, tag, push) for all operator subprojects
	@echo "Running complete RAG workflow for all subprojects..."
	@for subproject in $(SUBPROJECTS); do \
		echo ""; \
		echo "=== Processing $$subproject ==="; \
		$(MAKE_ABS) -C $$subproject RAG_IMAGE_USERNAME=$(RAG_IMAGE_USERNAME) TARGET_PLATFORM=$(TARGET_PLATFORM) TARGET_ARCH=$(TARGET_ARCH) CONTAINER_ENGINE=$(CONTAINER_ENGINE) rag-all || exit 1; \
	done
	@echo ""
	@echo "All RAG workflows completed successfully."

.PHONY: rag-clean-all
rag-clean-all: ## Clean RAG artifacts for all operator subprojects
	@echo "Cleaning RAG artifacts for all subprojects..."
	@for subproject in $(SUBPROJECTS); do \
		echo ""; \
		echo "=== Cleaning $$subproject ==="; \
		$(MAKE_ABS) -C $$subproject rag-clean || exit 1; \
	done
	@echo ""
	@echo "All RAG artifacts cleaned."

# Multi-arch targets that run across all subprojects
.PHONY: rag-build-multiarch-all
rag-build-multiarch-all: ## Build multi-arch RAG images (amd64 + arm64) for all operator subprojects
	@echo "Building multi-arch RAG images for all subprojects..."
	@for subproject in $(SUBPROJECTS); do \
		echo ""; \
		echo "=== Building multi-arch for $$subproject ==="; \
		$(MAKE_ABS) -C $$subproject RAG_IMAGE_USERNAME=$(RAG_IMAGE_USERNAME) CONTAINER_ENGINE=$(CONTAINER_ENGINE) rag-build-multiarch || exit 1; \
	done
	@echo ""
	@echo "All multi-arch RAG images built successfully."

.PHONY: rag-load-multiarch-all
rag-load-multiarch-all: ## Load multi-arch RAG images for all operator subprojects
	@echo "Loading multi-arch RAG images for all subprojects..."
	@for subproject in $(SUBPROJECTS); do \
		echo ""; \
		echo "=== Loading multi-arch for $$subproject ==="; \
		$(MAKE_ABS) -C $$subproject RAG_IMAGE_USERNAME=$(RAG_IMAGE_USERNAME) CONTAINER_ENGINE=$(CONTAINER_ENGINE) rag-load-multiarch || exit 1; \
	done
	@echo ""
	@echo "All multi-arch RAG images loaded successfully."

.PHONY: rag-tag-multiarch-all
rag-tag-multiarch-all: ## Tag multi-arch RAG images for all operator subprojects
	@echo "Tagging multi-arch RAG images for all subprojects..."
	@for subproject in $(SUBPROJECTS); do \
		echo ""; \
		echo "=== Tagging multi-arch for $$subproject ==="; \
		$(MAKE_ABS) -C $$subproject RAG_IMAGE_USERNAME=$(RAG_IMAGE_USERNAME) CONTAINER_ENGINE=$(CONTAINER_ENGINE) rag-tag-multiarch || exit 1; \
	done
	@echo ""
	@echo "All multi-arch RAG images tagged successfully."

.PHONY: rag-push-multiarch-all
rag-push-multiarch-all: ## Push multi-arch RAG images for all operator subprojects
	@echo "Pushing multi-arch RAG images for all subprojects..."
	@for subproject in $(SUBPROJECTS); do \
		echo ""; \
		echo "=== Pushing multi-arch for $$subproject ==="; \
		$(MAKE_ABS) -C $$subproject RAG_IMAGE_USERNAME=$(RAG_IMAGE_USERNAME) CONTAINER_ENGINE=$(CONTAINER_ENGINE) rag-push-multiarch || exit 1; \
	done
	@echo ""
	@echo "All multi-arch RAG images pushed successfully."

.PHONY: rag-all-multiarch-all
rag-all-multiarch-all: ## Complete multi-arch workflow for all operator subprojects
	@echo "Running complete multi-arch RAG workflow for all subprojects..."
	@for subproject in $(SUBPROJECTS); do \
		echo ""; \
		echo "=== Processing multi-arch for $$subproject ==="; \
		$(MAKE_ABS) -C $$subproject RAG_IMAGE_USERNAME=$(RAG_IMAGE_USERNAME) CONTAINER_ENGINE=$(CONTAINER_ENGINE) rag-all-multiarch || exit 1; \
	done
	@echo ""
	@echo "All multi-arch RAG workflows completed successfully."

.PHONY: rag-help
rag-help: ## Display help for RAG-related targets
	@echo "Lightspeed Telco RAG Models - Root Makefile"
	@echo ""
	@echo "Root-level RAG Targets (run across all subprojects):"
	@echo "  rag-build-all  - Build RAG images for all operator subprojects"
	@echo "  rag-load-all   - Load RAG images for all operator subprojects"
	@echo "  rag-tag-all    - Tag RAG images for all operator subprojects"
	@echo "  rag-push-all   - Push RAG images for all operator subprojects"
	@echo "  rag-all-all    - Complete workflow for all operator subprojects"
	@echo "  rag-clean-all  - Clean RAG artifacts for all operator subprojects"
	@echo ""
	@echo "Multi-Arch Targets (build x86, extract DB, create arm64):"
	@echo "  rag-build-multiarch-all  - Build multi-arch RAG images (amd64 + arm64)"
	@echo "  rag-load-multiarch-all   - Load multi-arch RAG images"
	@echo "  rag-tag-multiarch-all    - Tag multi-arch RAG images"
	@echo "  rag-push-multiarch-all   - Push multi-arch RAG images and create manifest"
	@echo "  rag-all-multiarch-all    - Complete multi-arch workflow"
	@echo ""
	@echo "Lint Targets:"
	@echo "  lint          - Run all linters (yamllint, mdlint)"
	@echo "  yamllint      - Lint YAML files"
	@echo "  mdlint        - Lint Markdown files (pymarkdownlnt)"
	@echo "  markdown-lint - Alias for mdlint"
	@echo ""
	@echo "Subprojects:"
	@for subproject in $(SUBPROJECTS); do \
		echo "  - $$subproject"; \
	done
	@echo ""
	@echo "Usage:"
	@echo "  make RAG_IMAGE_USERNAME=myusername rag-all-all"
	@echo "  # Default: builds multi-arch (amd64 + arm64)"
	@echo ""
	@echo "  make RAG_IMAGE_USERNAME=myusername TARGET_ARCH=amd64 rag-all-all"
	@echo "  # Build only amd64 architecture"
	@echo ""
	@echo "  make RAG_IMAGE_USERNAME=myusername TARGET_ARCH=arm64 rag-all-all"
	@echo "  # Build only arm64 architecture (requires amd64 build first)"
	@echo ""
	@echo "To run targets for a specific subproject:"
	@echo "  cd <subproject> && make RAG_IMAGE_USERNAME=myusername rag-all"
	@echo "  # Default: builds multi-arch"
	@echo ""
	@echo "  cd <subproject> && make RAG_IMAGE_USERNAME=myusername TARGET_ARCH=amd64 rag-all"
	@echo "  # Build only amd64"
	@echo ""
	@echo "For detailed help on individual subproject targets:"
	@echo "  cd <subproject> && make rag-help"

.PHONY: help
help: rag-help ## Display help information (alias for rag-help)

.PHONY: venv yamllint mdlint lint
venv: $(VENV)

# This rule creates the Python virtual environment if it doesn't exist
# or if the requirements file has been updated.
$(VENV): $(ROOT_DIR)/requirements.txt
	$(PY) -m venv $(VENV)
	$(BIN)/pip install --upgrade pip
	$(BIN)/pip install --upgrade -r $(ROOT_DIR)/requirements.txt
	touch $(VENV)

## lint: Run all linters (yamllint, mdlint)
lint: yamllint mdlint
	@echo "All linters passed."

## yamllint: Lint YAML files (config in .yamllint.yaml)
yamllint: venv
	$(BIN)/yamllint -c $(ROOT_DIR)/.yamllint.yaml .

## mdlint: Lint Markdown files (config: .pymarkdownlnt.json, MD013 disabled)
mdlint: venv
	$(BIN)/pymarkdownlnt -c $(ROOT_DIR)/.pymarkdownlnt.json scan $(shell find $(ROOT_DIR) -path $(ROOT_DIR)/venv -prune -o -type f -name "*.md" -print)

.PHONY: markdown-lint
markdown-lint: mdlint ## Lint all markdown files in the project (alias for mdlint)

.PHONY: clean
clean: rag-clean-all ## Clean venv and Python cache
	rm -rf $(VENV)
	find $(ROOT_DIR) -type f -name '*.pyc' -delete
	find $(ROOT_DIR) -type d -name __pycache__ -delete
	@echo "Virtual environment and Python cache removed."
