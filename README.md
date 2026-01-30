<!-- SPDX-License-Identifier: Apache-2.0 -->

# Lightspeed Telco RAG Models

This repository contains the infrastructure and content for generating
Retrieval-Augmented Generation (RAG) database images for use with OpenShift
Lightspeed Service's BYO Knowledge (Bring Your Own Knowledge) feature. These RAG
images provide custom knowledge to Large Language Models (LLMs) for
telco-related operators.

## Overview

The BYO Knowledge tool allows you to customize the information available to the
LLM by providing access to container images containing RAG databases. This
repository automates the process of building, tagging, and pushing these RAG
images to container registries.

**Important:** The BYO Knowledge tool is a Technology Preview feature only.
Technology Preview features are not supported with Red Hat production service
level agreements (SLAs) and might not be functionally complete. Red Hat does
not recommend using them in production.

## Project Structure

```text
lightspeed-telco-rag-models/
├── Makefile                    # Root Makefile for running targets across all subprojects
├── subproject.mk               # Generic Makefile targets for RAG image generation
├── Containerfile.template      # Template for building multi-arch images with custom labels
├── ptp-operator/              # PTP Operator RAG content
│   ├── Makefile
│   └── content/               # Markdown files for RAG database
└── telco-reference-design-specification/  # Telco Reference Design RAG
    ├── Makefile
    └── content/               # Markdown files for RAG database
```

## Prerequisites

Before using this repository, ensure you have:

1. **OpenShift Container Platform access** with permission to create
   cluster-scoped custom resources (e.g., `cluster-admin` role)
2. **LLM provider** available for use with OpenShift Lightspeed Service
3. **OpenShift Lightspeed Operator** installed
4. **Podman** installed and configured
5. **Logged in to registry.redhat.io** using Podman:

   ```bash
   podman login registry.redhat.io
   ```

6. **Container image registry account** (e.g., quay.io account)
7. **Markdown files** (`.md` extension only) containing the custom knowledge
   you want to add to the RAG database

## Quick Start

### 1. Set Your Registry Username

Set the `RAG_IMAGE_USERNAME` environment variable or pass it on the command line:

```bash
export RAG_IMAGE_USERNAME=myusername
```

### 2. Build and Push All RAG Images

From the root directory, run:

```bash
make RAG_IMAGE_USERNAME=myusername rag-all-all
```

This will build, load, tag, and push multi-arch RAG images (amd64 + arm64) for all subprojects. The build process:
1. Runs the BYOK tool to generate the initial amd64 image
2. Extracts the RAG database from the amd64 image
3. Rebuilds the amd64 image using the Containerfile template (with your custom labels)
4. Builds the arm64 image using the same Containerfile template
5. Creates a multi-arch manifest for both architectures

### 3. Build and Push a Single Subproject

Navigate to a specific subproject directory:

```bash
cd ptp-operator
make RAG_IMAGE_USERNAME=myusername rag-all
```

Or:

```bash
cd telco-reference-design-specification
make RAG_IMAGE_USERNAME=myusername rag-all
```

## Available Targets

### Root-Level Targets (Run Across All Subprojects)

From the root directory:

- `make rag-build-all` - Build RAG images for all operator subprojects (default: multi-arch)
- `make rag-load-all` - Load RAG images for all operator subprojects
- `make rag-tag-all` - Tag RAG images for all operator subprojects
- `make rag-push-all` - Push RAG images for all operator subprojects
- `make rag-all-all` - Complete workflow (build, load, tag, push) for all subprojects
- `make rag-clean-all` - Clean RAG artifacts for all subprojects
- `make rag-help` or `make help` - Display help information

**Multi-Arch Targets:**
- `make rag-build-multiarch-all` - Build multi-arch RAG images (amd64 + arm64) for all subprojects
- `make rag-load-multiarch-all` - Load multi-arch RAG images for all subprojects
- `make rag-tag-multiarch-all` - Tag multi-arch RAG images for all subprojects
- `make rag-push-multiarch-all` - Push multi-arch RAG images and create manifests for all subprojects
- `make rag-all-multiarch-all` - Complete multi-arch workflow for all subprojects

### Subproject-Level Targets (Run in Individual Subproject Directories)

From any subproject directory:

- `make rag-build` - Build RAG image (default: multi-arch, use TARGET_ARCH to override)
- `make rag-load` - Load the generated RAG image into podman
- `make rag-tag` - Tag the local RAG image for registry push
- `make rag-push` - Push the RAG image to the container registry
- `make rag-all` - Run complete workflow: build, load, tag, and push
- `make rag-clean` - Clean generated RAG image artifacts
- `make rag-help` - Display help for RAG-related targets

**Multi-Arch Targets:**
- `make rag-run-byok-tool` - Run BYOK tool to generate initial amd64 image
- `make rag-extract-db` - Extract RAG database from BYOK-generated amd64 image
- `make rag-build-amd64` - Build final amd64 image using Containerfile template
- `make rag-build-arm64` - Build arm64 image using extracted database and Containerfile template
- `make rag-build-multiarch` - Build both amd64 and arm64 images
- `make rag-load-multiarch` - Load both amd64 and arm64 images
- `make rag-tag-multiarch` - Tag both architectures for registry push
- `make rag-push-multiarch` - Push both architectures and create multi-arch manifest
- `make rag-all-multiarch` - Complete multi-arch workflow

## Configuration

### Required Variables

- `RAG_IMAGE_USERNAME` - Your container registry username (e.g., quay.io username)
  - Must be set via command line or environment variable
  - Example: `make RAG_IMAGE_USERNAME=myusername rag-all`

### Optional Variables

These can be overridden in subproject Makefiles or via command line:

- `RAG_IMAGE_REGISTRY` - Container registry (default: `quay.io`)
- `RAG_IMAGE_TAG` - Image tag (default: `latest`)
- `RAG_TOOL_IMAGE` - RAG tool container image (default: `registry.redhat.io/openshift-lightspeed-tech-preview/lightspeed-rag-tool-rhel9:latest`)
- `CONTENT_DIR` - Directory with markdown files (default: `content`)
- `OUTPUT_DIR` - Directory for generated image tar (default: `output`)
- `TARGET_ARCH` - Target architecture: `multi` (default, builds both amd64 and arm64), `amd64`, `arm64`, `x86_64` (normalized to amd64), or `aarch64` (normalized to arm64)
- `CONTAINERFILE_TEMPLATE` - Path to Containerfile template for building images with custom labels (default: `root/Containerfile.template`)
- `CONTAINER_ENGINE` - Container engine to use (default: `podman`)

## Usage Examples

### Example 1: Build and Push All Subprojects

```bash
# Set your registry username
export RAG_IMAGE_USERNAME=myusername

# Run complete workflow for all subprojects
make rag-all-all
```

### Example 2: Build Only (No Push)

```bash
# Build images for all subprojects
make RAG_IMAGE_USERNAME=myusername rag-build-all

# Later, push when ready
make RAG_IMAGE_USERNAME=myusername rag-push-all
```

### Example 3: Single Subproject Workflow

```bash
cd ptp-operator
make RAG_IMAGE_USERNAME=myusername rag-all
```

### Example 4: Custom Registry and Tag

```bash
make RAG_IMAGE_USERNAME=myusername \
     RAG_IMAGE_REGISTRY=myregistry.com \
     RAG_IMAGE_TAG=v1.0.0 \
     rag-all-all
```

### Example 5: Build Single Architecture

```bash
# Build only amd64 architecture
make RAG_IMAGE_USERNAME=myusername TARGET_ARCH=amd64 rag-all-all

# Build only arm64 architecture (still requires amd64 build internally)
make RAG_IMAGE_USERNAME=myusername TARGET_ARCH=arm64 rag-all-all
```

### Example 6: Multi-Arch Workflow

```bash
# Explicitly build multi-arch (this is the default)
make RAG_IMAGE_USERNAME=myusername TARGET_ARCH=multi rag-all-all

# Or use the dedicated multi-arch target
make RAG_IMAGE_USERNAME=myusername rag-all-multiarch-all
```

## Generated Images

The following images will be created and pushed to your registry:

- `quay.io/<username>/ptp-operator-byok:latest` (multi-arch manifest with amd64 and arm64)
- `quay.io/<username>/telco-reference-design-specification-byok:latest` (multi-arch manifest with amd64 and arm64)

When building with `TARGET_ARCH=multi` (the default), a multi-arch manifest is created that points to both amd64 and arm64 images. The same image name works on both x86_64 and ARM64 platforms.

## Adding Content

To add custom knowledge to any subproject:

1. Navigate to the subproject's `content/` directory
2. Add or modify Markdown files (`.md` extension only)
3. Run the build process:

   ```bash
   cd <operator-directory>
   make RAG_IMAGE_USERNAME=myusername rag-all
   ```

The BYOK tool will process all Markdown files in the `content/` directory and
create a RAG database image.

## Customizing Image Labels

The repository includes a `Containerfile.template` file that is used to build both amd64 and arm64 images with consistent labels and metadata. You can customize this template to add your own labels, environment variables, and other container metadata.

1. Edit `Containerfile.template` in the root directory
2. Add your custom labels, environment variables, exposed ports, etc.
3. The template will be used for both architectures automatically

Example labels in the template:

```dockerfile
LABEL description="Lightspeed BYOK RAG Database Image for ${RAG_IMAGE_NAME}"
LABEL io.k8s.description="Lightspeed BYOK RAG Database Image for ${RAG_IMAGE_NAME}"
LABEL version="0.0.1"
```

The `${RAG_IMAGE_NAME}` variable is automatically set during the build process.

## Troubleshooting

### Build does not work on my computer

The Lightspeed BYOK tool only works on Linux x86 (amd64). However, this repository automatically builds multi-arch images:
- The BYOK tool runs on amd64 to generate the initial image
- The RAG database is extracted (it's cross-platform)
- Both amd64 and arm64 images are built using the Containerfile template
- A multi-arch manifest is created for both architectures

This means you can build multi-arch images even if you're only running on x86, and the resulting images will work on both x86_64 and ARM64 platforms.

However, this does not mean it will work on macOS as the underlying Lightspeed BYOK tool does not work on macOS.

References:
- <https://redhat-internal.slack.com/archives/C068JAU4Y0P/p1764245547671739?thread_ts=1764243676.511759&cid=C068JAU4Y0P>
- <https://github.com/openshift/lightspeed-rag-content/tree/main/byok>
- <https://redhat-internal.slack.com/archives/C068JAU4Y0P/p1767800833428219>

### Authentication File Not Found

If you see an error about the authentication file:

```text
Error: Authentication file not found at /run/user/0/containers/auth.json
```

Solution: Log in to registry.redhat.io:

```bash
podman login registry.redhat.io
```

The path may also need to be specified manually using `AUTH_JSON="/my/example/path" make ...`

### Image Not Found After Build

If the image tar file is not created after building:
- Check that the `content/` directory contains `.md` files
- Verify podman has access to `/dev/fuse` device
- Check that you're logged in to registry.redhat.io

### Push Fails

If pushing to the registry fails:
- Verify you're logged in to the target registry:

  ```bash
  podman login quay.io
  ```

- Check that you have push permissions for the repository
- Verify the image was tagged correctly: `podman images`

## Project Status

This project is actively maintained and supports the following telco operators
and specifications:

- **PTP Operator** - Precision Time Protocol operator for network time
  synchronization
- **Telco Reference Design Specification** - Reference design specifications
  and documentation for telco deployments

## Contributing

To contribute to this project:

1. Add or modify Markdown files in the appropriate subproject's `content/` directory
2. Test your changes by building the RAG image locally
3. Submit changes via merge request

## Support

For issues or questions:

- Open an issue in this GitLab repository
- Refer to the [OpenShift Lightspeed documentation](https://docs.openshift.com/)
- Check the help targets: `make rag-help` or `cd <operator> && make rag-help`

## License

This project follows Red Hat's standard licensing terms for Technology Preview features.
