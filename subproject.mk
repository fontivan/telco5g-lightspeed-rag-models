# SPDX-License-Identifier: Apache-2.0
# Generic Makefile targets for BYO Knowledge RAG image generation
# This file provides reusable targets for building, tagging, and pushing RAG images
# to container registries for use with OpenShift Lightspeed Service

# Note: SHELL must be set in the including Makefile BEFORE including this file
# This prevents make from re-executing when SHELL is set in an included file
# (which causes "Error during reexec" in old make versions like 3.81)

# Default values - can be overridden in subproject Makefiles
RAG_IMAGE_NAME ?= $(error RAG_IMAGE_NAME must be set in subproject Makefile)
RAG_IMAGE_REGISTRY ?= quay.io
# RAG_IMAGE_USERNAME is optional for clean targets, but required for build/push targets
# It will be checked when actually needed (in rag-tag, rag-push, etc.)
RAG_IMAGE_USERNAME ?= 
RAG_IMAGE_TAG ?= latest
RAG_TOOL_IMAGE ?= registry.redhat.io/openshift-lightspeed-tech-preview/lightspeed-rag-tool-rhel9:latest
CONTENT_DIR ?= content
OUTPUT_DIR ?= output

# Containerfile template path - defaults to root Containerfile.template, can be overridden per subproject
# If PARENT_DIR is set (from subproject Makefile), use it; otherwise calculate from subproject.mk location
ifeq ($(origin PARENT_DIR),undefined)
  PARENT_DIR := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
endif
CONTAINERFILE_TEMPLATE ?= $(PARENT_DIR)/Containerfile.template

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

# Derived variables
LOCAL_IMAGE_NAME := localhost/$(RAG_IMAGE_NAME)
FULL_IMAGE_NAME := $(RAG_IMAGE_REGISTRY)/$(RAG_IMAGE_USERNAME)/$(RAG_IMAGE_NAME):$(RAG_IMAGE_TAG)
IMAGE_TAR := $(OUTPUT_DIR)/$(RAG_IMAGE_NAME).tar
AUTH_JSON ?= $(XDG_RUNTIME_DIR)/containers/auth.json
# Stamp file to track configuration changes (platform, arch, username, etc.)
CONFIG_STAMP := $(OUTPUT_DIR)/.config-stamp
# Multi-arch support variables
AMD64_IMAGE_TAR := $(OUTPUT_DIR)/$(RAG_IMAGE_NAME)-amd64.tar
ARM64_IMAGE_TAR := $(OUTPUT_DIR)/$(RAG_IMAGE_NAME)-arm64.tar
AMD64_LOCAL_IMAGE := $(LOCAL_IMAGE_NAME)-amd64
ARM64_LOCAL_IMAGE := $(LOCAL_IMAGE_NAME)-arm64
AMD64_FULL_IMAGE := $(FULL_IMAGE_NAME)-amd64
ARM64_FULL_IMAGE := $(FULL_IMAGE_NAME)-arm64
DB_EXTRACT_DIR := $(OUTPUT_DIR)/rag-db-extract

.PHONY: rag-build
rag-build: ## Build RAG image from markdown files in content directory
	@if [ "$(TARGET_ARCH)" = "multi" ]; then \
		echo "Building multi-arch RAG images (amd64 + arm64)..."; \
		$(MAKE) rag-build-multiarch; \
	elif [ "$(TARGET_ARCH)" = "amd64" ]; then \
		echo "Building AMD64 RAG image..."; \
		$(MAKE) rag-build-amd64; \
		cp $(AMD64_IMAGE_TAR) $(IMAGE_TAR); \
		echo "RAG image built: $(IMAGE_TAR)"; \
	elif [ "$(TARGET_ARCH)" = "arm64" ]; then \
		echo "Building ARM64 RAG image (requires amd64 build first)..."; \
		$(MAKE) rag-build-multiarch; \
		cp $(ARM64_IMAGE_TAR) $(IMAGE_TAR); \
		echo "RAG image built: $(IMAGE_TAR)"; \
	else \
		echo "Error: TARGET_ARCH must be 'multi', 'amd64', or 'arm64'"; \
		exit 1; \
	fi

# Stamp file rule: creates/updates the stamp file with current configuration
# This ensures the stamp file exists as a dependency
$(CONFIG_STAMP):
	@mkdir -p $(OUTPUT_DIR)
	@CURRENT_CONFIG="$(TARGET_PLATFORM)|$(TARGET_ARCH)|$(RAG_IMAGE_USERNAME)|$(RAG_IMAGE_REGISTRY)|$(RAG_IMAGE_TAG)|$(RAG_TOOL_IMAGE)|$(CONTAINER_ENGINE)"; \
	echo "$$CURRENT_CONFIG" > $(CONFIG_STAMP)

$(IMAGE_TAR): $(CONTENT_DIR) $(CONFIG_STAMP)
	@# Check if configuration changed and force rebuild if needed
	@CURRENT_CONFIG="$(TARGET_PLATFORM)|$(TARGET_ARCH)|$(RAG_IMAGE_USERNAME)|$(RAG_IMAGE_REGISTRY)|$(RAG_IMAGE_TAG)|$(RAG_TOOL_IMAGE)|$(CONTAINER_ENGINE)"; \
	if [ -f "$(CONFIG_STAMP)" ] && [ "$$CURRENT_CONFIG" != "$$(cat $(CONFIG_STAMP) 2>/dev/null)" ]; then \
		echo "Configuration changed (platform, arch, or username), removing old image to force rebuild..."; \
		rm -f "$(IMAGE_TAR)"; \
		echo "$$CURRENT_CONFIG" > $(CONFIG_STAMP); \
	fi
	@echo "Building RAG image from markdown files in $(CONTENT_DIR)..."
	@mkdir -p $(OUTPUT_DIR)
	@if [ ! -f "$(AUTH_JSON)" ]; then \
		echo "Error: Authentication file not found at $(AUTH_JSON)"; \
		echo "Please log in to registry.redhat.io using: $(CONTAINER_ENGINE) login registry.redhat.io"; \
		exit 1; \
	fi
	@CONTENT_ABS=$$(cd $(abspath $(CONTENT_DIR)) && pwd) && \
	OUTPUT_ABS=$$(cd $(abspath $(OUTPUT_DIR)) && pwd) && \
	if [ -c /dev/fuse ]; then \
		$(CONTAINER_ENGINE) run --rm --privileged --platform "$(TARGET_PLATFORM)/$(TARGET_ARCH)" --device=/dev/fuse \
			-v "$(AUTH_JSON):/run/user/0/containers/auth.json:Z" \
			-v "$$CONTENT_ABS:/markdown:Z" \
			-v "$$OUTPUT_ABS:/output:Z" \
			"$(RAG_TOOL_IMAGE)"; \
	else \
		$(CONTAINER_ENGINE) run --rm --privileged --platform "$(TARGET_PLATFORM)/$(TARGET_ARCH)" \
			-v "$(AUTH_JSON):/run/user/0/containers/auth.json:Z" \
			-v "$$CONTENT_ABS:/markdown:Z" \
			-v "$$OUTPUT_ABS:/output:Z" \
			"$(RAG_TOOL_IMAGE)"; \
	fi
	@if [ ! -f "$(IMAGE_TAR)" ]; then \
		if [ -f "$(OUTPUT_DIR)/byok-image.tar" ]; then \
			echo "Renaming byok-image.tar to $(notdir $(IMAGE_TAR))..."; \
			mv "$(OUTPUT_DIR)/byok-image.tar" "$(IMAGE_TAR)"; \
		else \
			echo "Error: RAG image tar file not found at $(IMAGE_TAR)"; \
			echo "Also checked for $(OUTPUT_DIR)/byok-image.tar"; \
			exit 1; \
		fi; \
	fi
	@echo "RAG image tar created: $(IMAGE_TAR)"

.PHONY: rag-load
rag-load: rag-build ## Load the generated RAG image into container engine
	@if [ "$(TARGET_ARCH)" = "multi" ]; then \
		$(MAKE) rag-load-multiarch; \
	else \
		echo "Loading RAG image from $(IMAGE_TAR)..."; \
		LOADED_IMAGE=$$($(CONTAINER_ENGINE) load < $(IMAGE_TAR) 2>&1 | grep "Loaded image:" | sed 's/.*Loaded image: //' | head -1) && \
		if [ -n "$$LOADED_IMAGE" ]; then \
			echo "Image loaded as: $$LOADED_IMAGE"; \
			if [ "$$LOADED_IMAGE" != "$(LOCAL_IMAGE_NAME):$(RAG_IMAGE_TAG)" ]; then \
				echo "Tagging $$LOADED_IMAGE as $(LOCAL_IMAGE_NAME):$(RAG_IMAGE_TAG)..."; \
				$(CONTAINER_ENGINE) tag "$$LOADED_IMAGE" "$(LOCAL_IMAGE_NAME):$(RAG_IMAGE_TAG)"; \
			fi; \
		else \
			echo "Warning: Could not determine loaded image name, assuming $(LOCAL_IMAGE_NAME):$(RAG_IMAGE_TAG)"; \
		fi && \
		echo "RAG image loaded: $(LOCAL_IMAGE_NAME):$(RAG_IMAGE_TAG)"; \
	fi

.PHONY: rag-tag
rag-tag: rag-load ## Tag the local RAG image for registry push
	@if [ -z "$(RAG_IMAGE_USERNAME)" ]; then \
		echo "Error: RAG_IMAGE_USERNAME must be set for rag-tag target"; \
		echo "Usage: make RAG_IMAGE_USERNAME=myusername rag-tag"; \
		exit 1; \
	fi
	@if [ "$(TARGET_ARCH)" = "multi" ]; then \
		$(MAKE) rag-tag-multiarch; \
	else \
		echo "Tagging image $(LOCAL_IMAGE_NAME):$(RAG_IMAGE_TAG) as $(FULL_IMAGE_NAME)..."; \
		$(CONTAINER_ENGINE) tag $(LOCAL_IMAGE_NAME):$(RAG_IMAGE_TAG) $(FULL_IMAGE_NAME) && \
		echo "Image tagged: $(FULL_IMAGE_NAME)"; \
	fi

.PHONY: rag-push
rag-push: rag-tag ## Push the RAG image to the container registry
	@if [ -z "$(RAG_IMAGE_USERNAME)" ]; then \
		echo "Error: RAG_IMAGE_USERNAME must be set for rag-push target"; \
		echo "Usage: make RAG_IMAGE_USERNAME=myusername rag-push"; \
		exit 1; \
	fi
	@if [ "$(TARGET_ARCH)" = "multi" ]; then \
		$(MAKE) rag-push-multiarch; \
	else \
		echo "Pushing image $(FULL_IMAGE_NAME) to registry..."; \
		$(CONTAINER_ENGINE) push $(FULL_IMAGE_NAME) && \
		echo "Image pushed successfully: $(FULL_IMAGE_NAME)"; \
	fi

.PHONY: rag-all
rag-all: rag-push ## Build, load, tag, and push RAG image (complete workflow)

.PHONY: rag-clean
rag-clean: ## Clean generated RAG image artifacts
	@echo "Cleaning RAG image artifacts..."
	rm -rf $(OUTPUT_DIR)
	@echo "RAG image artifacts cleaned"

# Multi-arch support: Run BYOK tool to generate initial amd64 image
BYOK_IMAGE_TAR := $(OUTPUT_DIR)/byok-image.tar

.PHONY: rag-run-byok-tool
rag-run-byok-tool: $(BYOK_IMAGE_TAR) ## Run BYOK tool to generate initial amd64 image from markdown files

$(BYOK_IMAGE_TAR): $(CONTENT_DIR)
	@echo "Running BYOK tool to build RAG image from markdown files in $(CONTENT_DIR)..."
	@mkdir -p $(OUTPUT_DIR)
	@if [ ! -f "$(AUTH_JSON)" ]; then \
		echo "Error: Authentication file not found at $(AUTH_JSON)"; \
		echo "Please log in to registry.redhat.io using: $(CONTAINER_ENGINE) login registry.redhat.io"; \
		exit 1; \
	fi
	@CONTENT_ABS=$$(cd $(abspath $(CONTENT_DIR)) && pwd) && \
	OUTPUT_ABS=$$(cd $(abspath $(OUTPUT_DIR)) && pwd) && \
	if [ -c /dev/fuse ]; then \
		$(CONTAINER_ENGINE) run --rm --privileged --platform "linux/amd64" --device=/dev/fuse \
			-v "$(AUTH_JSON):/run/user/0/containers/auth.json:Z" \
			-v "$$CONTENT_ABS:/markdown:Z" \
			-v "$$OUTPUT_ABS:/output:Z" \
			"$(RAG_TOOL_IMAGE)"; \
	else \
		$(CONTAINER_ENGINE) run --rm --privileged --platform "linux/amd64" \
			-v "$(AUTH_JSON):/run/user/0/containers/auth.json:Z" \
			-v "$$CONTENT_ABS:/markdown:Z" \
			-v "$$OUTPUT_ABS:/output:Z" \
			"$(RAG_TOOL_IMAGE)"; \
	fi
	@if [ ! -f "$(OUTPUT_DIR)/byok-image.tar" ]; then \
		echo "Error: BYOK tool did not produce byok-image.tar"; \
		exit 1; \
	fi
	@echo "BYOK tool completed: $(BYOK_IMAGE_TAR)"

# Build final amd64 image using Containerfile template
.PHONY: rag-build-amd64
rag-build-amd64: rag-extract-db $(AMD64_IMAGE_TAR) ## Build final amd64 RAG image using Containerfile template
	@echo "AMD64 RAG image built: $(AMD64_IMAGE_TAR)"

$(AMD64_IMAGE_TAR): rag-extract-db
	@if [ ! -d "$(DB_EXTRACT_DIR)/rag" ]; then \
		echo "Error: RAG database not extracted. Run 'rag-extract-db' first."; \
		exit 1; \
	fi
	@if [ ! -f "$(CONTAINERFILE_TEMPLATE)" ]; then \
		echo "Error: Containerfile template not found at $(CONTAINERFILE_TEMPLATE)"; \
		echo "Please create a Containerfile.template file or set CONTAINERFILE_TEMPLATE variable"; \
		exit 1; \
	fi
	@echo "Building AMD64 image with Containerfile template..."
	@cp "$(CONTAINERFILE_TEMPLATE)" $(OUTPUT_DIR)/Containerfile.amd64
	@$(CONTAINER_ENGINE) build --platform linux/amd64 \
		--build-arg RAG_IMAGE_NAME=$(RAG_IMAGE_NAME) \
		-f $(OUTPUT_DIR)/Containerfile.amd64 \
		-t $(AMD64_LOCAL_IMAGE):$(RAG_IMAGE_TAG) \
		$(OUTPUT_DIR)
	@echo "Saving AMD64 image to tar..."
	@if [ -f "$(AMD64_IMAGE_TAR)" ]; then \
		rm -f $(AMD64_IMAGE_TAR); \
	fi
	@$(CONTAINER_ENGINE) save $(AMD64_LOCAL_IMAGE):$(RAG_IMAGE_TAG) -o $(AMD64_IMAGE_TAR)
	@echo "AMD64 image built with template: $(AMD64_IMAGE_TAR)"

# Extract RAG database from BYOK-generated amd64 image
.PHONY: rag-extract-db
rag-extract-db: $(BYOK_IMAGE_TAR) ## Extract RAG database from BYOK-generated amd64 image
	@echo "Extracting RAG database from BYOK-generated AMD64 image..."
	@mkdir -p $(DB_EXTRACT_DIR)
	@# Load the BYOK image and extract database
	@BYOK_LOADED=$$($(CONTAINER_ENGINE) load < $(BYOK_IMAGE_TAR) 2>&1 | grep "Loaded image:" | sed 's/.*Loaded image: //' | head -1); \
	if [ -z "$$BYOK_LOADED" ]; then \
		echo "Error: Failed to load BYOK image from $(BYOK_IMAGE_TAR)"; \
		exit 1; \
	fi; \
	echo "BYOK image loaded as: $$BYOK_LOADED"; \
	echo "Extracting RAG database from /rag..."; \
	$(CONTAINER_ENGINE) create --name rag-extract-tmp --platform "linux/amd64" "$$BYOK_LOADED" 2>/dev/null || \
		($(CONTAINER_ENGINE) rm rag-extract-tmp 2>/dev/null; $(CONTAINER_ENGINE) create --name rag-extract-tmp --platform "linux/amd64" "$$BYOK_LOADED"); \
	$(CONTAINER_ENGINE) cp rag-extract-tmp:/rag $(DB_EXTRACT_DIR)/ 2>/dev/null || \
		(echo "Error: Failed to extract /rag from image. Does the directory exist?"; $(CONTAINER_ENGINE) rm rag-extract-tmp 2>/dev/null; exit 1); \
	$(CONTAINER_ENGINE) rm rag-extract-tmp 2>/dev/null || true; \
	echo "RAG database extracted to: $(DB_EXTRACT_DIR)/rag"

# Build arm64 image with extracted database
.PHONY: rag-build-arm64
rag-build-arm64: rag-extract-db ## Build arm64 RAG image using database extracted from amd64 image
	@echo "Building ARM64 RAG image with extracted database..."
	@if [ ! -d "$(DB_EXTRACT_DIR)" ] || [ -z "$$(ls -A $(DB_EXTRACT_DIR) 2>/dev/null)" ]; then \
		echo "Error: RAG database not extracted. Run 'rag-extract-db' first."; \
		exit 1; \
	fi
	@if [ ! -d "$(DB_EXTRACT_DIR)/rag" ]; then \
		echo "Error: RAG database not found at $(DB_EXTRACT_DIR)/rag"; \
		exit 1; \
	fi
	@if [ ! -f "$(CONTAINERFILE_TEMPLATE)" ]; then \
		echo "Error: Containerfile template not found at $(CONTAINERFILE_TEMPLATE)"; \
		echo "Please create a Containerfile.template file or set CONTAINERFILE_TEMPLATE variable"; \
		exit 1; \
	fi
	@echo "Creating Containerfile from template..."
	@cp "$(CONTAINERFILE_TEMPLATE)" $(OUTPUT_DIR)/Containerfile.arm64
	@echo "Containerfile created from template: $(CONTAINERFILE_TEMPLATE)"
	@echo "Building ARM64 image..."
	@$(CONTAINER_ENGINE) build --platform linux/arm64 \
		--build-arg RAG_IMAGE_NAME=$(RAG_IMAGE_NAME) \
		-f $(OUTPUT_DIR)/Containerfile.arm64 \
		-t $(ARM64_LOCAL_IMAGE):$(RAG_IMAGE_TAG) \
		$(OUTPUT_DIR)
	@echo "Saving ARM64 image to tar..."
	@if [ -f "$(ARM64_IMAGE_TAR)" ]; then \
		rm -f $(ARM64_IMAGE_TAR); \
	fi
	@$(CONTAINER_ENGINE) save $(ARM64_LOCAL_IMAGE):$(RAG_IMAGE_TAG) -o $(ARM64_IMAGE_TAR)
	@echo "ARM64 RAG image built: $(ARM64_IMAGE_TAR)"

# Multi-arch workflow: build both architectures
.PHONY: rag-build-multiarch
rag-build-multiarch: rag-run-byok-tool rag-build-amd64 rag-build-arm64 ## Build RAG images for both amd64 and arm64 architectures
	@echo "Multi-arch RAG images built:"
	@echo "  AMD64: $(AMD64_IMAGE_TAR)"
	@echo "  ARM64: $(ARM64_IMAGE_TAR)"

# Load both architectures
.PHONY: rag-load-multiarch
rag-load-multiarch: rag-build-multiarch ## Load both amd64 and arm64 RAG images
	@echo "Loading AMD64 RAG image..."
	@AMD64_LOADED=$$($(CONTAINER_ENGINE) load < $(AMD64_IMAGE_TAR) 2>&1 | grep "Loaded image:" | sed 's/.*Loaded image: //' | head -1) && \
	if [ -n "$$AMD64_LOADED" ]; then \
		$(CONTAINER_ENGINE) tag "$$AMD64_LOADED" "$(AMD64_LOCAL_IMAGE):$(RAG_IMAGE_TAG)"; \
	fi
	@echo "Loading ARM64 RAG image..."
	@ARM64_LOADED=$$($(CONTAINER_ENGINE) load < $(ARM64_IMAGE_TAR) 2>&1 | grep "Loaded image:" | sed 's/.*Loaded image: //' | head -1) && \
	if [ -n "$$ARM64_LOADED" ]; then \
		$(CONTAINER_ENGINE) tag "$$ARM64_LOADED" "$(ARM64_LOCAL_IMAGE):$(RAG_IMAGE_TAG)"; \
	fi
	@echo "Multi-arch images loaded"

# Tag both architectures
.PHONY: rag-tag-multiarch
rag-tag-multiarch: rag-load-multiarch ## Tag both amd64 and arm64 images for registry push
	@if [ -z "$(RAG_IMAGE_USERNAME)" ]; then \
		echo "Error: RAG_IMAGE_USERNAME must be set for rag-tag-multiarch target"; \
		echo "Usage: make RAG_IMAGE_USERNAME=myusername rag-tag-multiarch"; \
		exit 1; \
	fi
	@echo "Tagging AMD64 image..."
	@$(CONTAINER_ENGINE) tag $(AMD64_LOCAL_IMAGE):$(RAG_IMAGE_TAG) $(AMD64_FULL_IMAGE)
	@echo "Tagging ARM64 image..."
	@$(CONTAINER_ENGINE) tag $(ARM64_LOCAL_IMAGE):$(RAG_IMAGE_TAG) $(ARM64_FULL_IMAGE)
	@echo "Multi-arch images tagged"

# Push both architectures and create manifest
.PHONY: rag-push-multiarch
rag-push-multiarch: rag-tag-multiarch ## Push both architectures and create multi-arch manifest
	@if [ -z "$(RAG_IMAGE_USERNAME)" ]; then \
		echo "Error: RAG_IMAGE_USERNAME must be set for rag-push-multiarch target"; \
		echo "Usage: make RAG_IMAGE_USERNAME=myusername rag-push-multiarch"; \
		exit 1; \
	fi
	@echo "Pushing AMD64 image..."
	@$(CONTAINER_ENGINE) push $(AMD64_FULL_IMAGE)
	@echo "Pushing ARM64 image..."
	@$(CONTAINER_ENGINE) push $(ARM64_FULL_IMAGE)
	@echo "Creating multi-arch manifest..."
	@# Remove existing manifest or image with same name if it exists
	@if $(CONTAINER_ENGINE) manifest exists $(FULL_IMAGE_NAME) 2>/dev/null; then \
		echo "Removing existing manifest: $(FULL_IMAGE_NAME)"; \
		$(CONTAINER_ENGINE) manifest rm $(FULL_IMAGE_NAME) 2>/dev/null || true; \
	fi
	@if $(CONTAINER_ENGINE) image exists $(FULL_IMAGE_NAME) 2>/dev/null; then \
		echo "Removing existing image with same name: $(FULL_IMAGE_NAME)"; \
		$(CONTAINER_ENGINE) rmi $(FULL_IMAGE_NAME) 2>/dev/null || true; \
	fi
	@$(CONTAINER_ENGINE) manifest create $(FULL_IMAGE_NAME) $(AMD64_FULL_IMAGE) $(ARM64_FULL_IMAGE)
	@$(CONTAINER_ENGINE) manifest push $(FULL_IMAGE_NAME) || \
		$(CONTAINER_ENGINE) manifest push --all $(FULL_IMAGE_NAME)
	@echo "Multi-arch manifest created and pushed: $(FULL_IMAGE_NAME)"

# Complete multi-arch workflow
.PHONY: rag-all-multiarch
rag-all-multiarch: rag-push-multiarch ## Complete multi-arch workflow: build, extract, create arm64, and push both architectures

.PHONY: rag-help
rag-help: ## Display help for RAG-related targets
	@echo "RAG Image Generation Targets:"
	@echo "  rag-build           - Build RAG image (default: multi-arch, use TARGET_ARCH to override)"
	@echo "  rag-load             - Load the generated RAG image into container engine"
	@echo "  rag-tag              - Tag the local RAG image for registry push"
	@echo "  rag-push             - Push the RAG image to the container registry"
	@echo "  rag-all              - Run complete workflow: build, load, tag, and push"
	@echo "  rag-clean            - Clean generated RAG image artifacts"
	@echo ""
	@echo "Multi-Arch Targets (for cross-platform support):"
	@echo "  rag-run-byok-tool - Run BYOK tool to generate initial amd64 image"
	@echo "  rag-extract-db       - Extract RAG database from BYOK-generated amd64 image"
	@echo "  rag-build-amd64      - Build final amd64 image using Containerfile template"
	@echo "  rag-build-arm64      - Build arm64 RAG image using extracted database"
	@echo "  rag-build-multiarch  - Build both amd64 and arm64 images"
	@echo "  rag-load-multiarch   - Load both amd64 and arm64 images"
	@echo "  rag-tag-multiarch    - Tag both architectures for registry push"
	@echo "  rag-push-multiarch   - Push both architectures and create multi-arch manifest"
	@echo "  rag-all-multiarch    - Complete multi-arch workflow"
	@echo ""
	@echo "Configuration variables (set in subproject Makefile):"
	@echo "  RAG_IMAGE_NAME      - Name of the RAG image (required)"
	@echo "  RAG_IMAGE_REGISTRY  - Container registry (default: quay.io)"
	@echo "  RAG_IMAGE_USERNAME  - Registry username (required)"
	@echo "  RAG_IMAGE_TAG       - Image tag (default: latest)"
	@echo "  RAG_TOOL_IMAGE      - RAG tool container image (default: registry.redhat.io/openshift-lightspeed-tech-preview/lightspeed-rag-tool-rhel9:latest)"
	@echo "  CONTENT_DIR         - Directory with markdown files (default: content)"
	@echo "  OUTPUT_DIR          - Directory for generated image tar (default: output)"
	@echo "  CONTAINERFILE_TEMPLATE - Path to Containerfile template for arm64 builds (default: root/Containerfile.template)"
	@echo "  TARGET_PLATFORM     - Target platform for container build (default: linux)"
	@echo "  TARGET_ARCH         - Target architecture: 'multi' (default, builds both), 'amd64', 'arm64', 'x86_64' (normalized to amd64), or 'aarch64' (normalized to arm64)"
	@echo "  CONTAINER_ENGINE    - Container engine to use (default: podman)"
