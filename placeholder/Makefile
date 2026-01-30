# SPDX-License-Identifier: Apache-2.0
# Makefile for telco-reference-design-specification RAG image generation
# Includes generic targets from subproject.mk

SHELL := /usr/bin/env bash

# Get the parent directory path
ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
PARENT_DIR := $(shell dirname $(ROOT_DIR))

# Required variables for RAG image generation
RAG_IMAGE_NAME := placeholder-byok
# RAG_IMAGE_USERNAME must be set via command line or environment variable
# Example: make RAG_IMAGE_USERNAME=myusername rag-all

# Include the generic subproject Makefile
include $(PARENT_DIR)/subproject.mk

.PHONY: help
help: rag-help ## Display help information
	@echo ""
	@echo "Placeholder RAG Image Targets:"
	@echo "  All RAG targets are available. See 'make rag-help' for details."

