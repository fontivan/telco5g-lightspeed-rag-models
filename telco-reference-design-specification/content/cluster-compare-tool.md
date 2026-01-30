<!-- SPDX-License-Identifier: Apache-2.0 -->

# Using the Cluster Compare Tool to Identify Reference Specification Misalignment

This guide describes how to use the [**kube-compare-mcp**](https://github.com/sakhoury/kube-compare-mcp) server and its MCP tools to detect when a Kubernetes or OpenShift cluster does not match a reference design specification (e.g., Red Hat Telco RDS). Use this when you need to answer questions such as:

- Example: **"Is my cluster aligned with the Telco Core RDS?"**
- Example: **"What is different between my cluster and the reference specification?"**
- Example: **"Which resources are missing or have drifted from the reference?"**

The **kube-compare-mcp** server exposes the [kube-compare](https://github.com/openshift/kube-compare) tool via the Model Context Protocol (MCP), so AI assistants (e.g., OpenShift Lightspeed, Cursor, Claude) can run comparisons and interpret results on your behalf.

---

## Overview: When to Use Which Tool

| Goal | Tool | Use when |
|------|------|----------|
| Validate against Red Hat Telco RDS (recommended) | **kube_compare_validate_rds** | You want to check compliance with Telco Core or Telco RAN DU RDS; the tool resolves the correct reference for your cluster version and runs the comparison. |
| Resolve the RDS reference only | **kube_compare_resolve_rds** | You need the exact container reference (e.g., for docs or automation) for your OpenShift version and RDS type. |
| Compare against an arbitrary reference | **kube_compare_cluster_diff** | You have a custom or non-RDS reference (HTTP URL or container image path to a `metadata.yaml`). |

For most alignment checks against Red Hat Telco reference designs, use **kube_compare_validate_rds**.

---

## 1. Validating Against Red Hat Telco RDS (Recommended)

**Purpose:** Determine whether the cluster is compliant with the Telco Core or Telco RAN DU Reference Design Specification and list any misalignments.

**How to check:**

1. Ensure the **kube-compare-mcp** server is available to your MCP client (e.g., deployed in-cluster for OpenShift Lightspeed, or configured in Cursor/Claude).
2. Call **kube_compare_validate_rds** with:
   - **rds_type**: `core` for Telco Core RDS, or `ran` for Telco RAN DU RDS.
   - **kubeconfig** and **context** (optional): if the cluster to check is remote; omit to use in-cluster config.
   - **output_format** (optional): `json`, `yaml`, or `junit` (default: `json`).
   - **all_resources** (optional): set to `true` to compare all resources of types mentioned in the reference; default `false` compares a representative subset.
3. If the MCP server runs outside the cluster or you need to target a specific cluster, provide kubeconfig (raw YAML or base64) and optionally **context**.

**Example prompts for an AI assistant:**

- Example: *"Compare my cluster against the Telco Core RDS."*
- Example: *"Check if my OpenShift cluster is compliant with the Telco RAN DU reference design."*
- Example: *"Run kube_compare_validate_rds for rds_type core and show the diffs."*

**Interpretation:**

- **No diffs, no missing resources** → Cluster is aligned with the reference specification for the compared resources.
- **Diffs and/or missing resources** → **Misalignment**: the cluster configuration has drifted or does not match the reference. Use the comparison output (see [Understanding comparison output](#understanding-comparison-output)) to identify which resources differ and how.
- **RDS resolution failure** (e.g., no image for cluster version, or registry auth error) → Fix cluster version detection or registry credentials; then re-run validation.

---

## 2. Resolving the RDS Reference for Your Cluster

**Purpose:** Get the exact reference URL (container image path to `metadata.yaml`) that matches your cluster’s OpenShift version and RDS type. Useful for documentation, automation, or before running a manual **kube_compare_cluster_diff**.

**How to check:**

1. Call **kube_compare_resolve_rds** with:
   - **rds_type**: `core` or `ran`.
   - **ocp_version** (optional): e.g. `4.18`, `4.20.0`; if omitted, the server derives the version from the cluster (requires kubeconfig or in-cluster config).
   - **kubeconfig** and **context** (optional): for the cluster to query for version; not needed if **ocp_version** is set.
2. Use the returned **reference** value (e.g. `container://registry.redhat.io/.../metadata.yaml`) in **kube_compare_cluster_diff** if you want to run a generic diff against that RDS.

**Example prompts:**

- Example: *"Find the Telco Core RDS reference for my OpenShift 4.18 cluster."*
- Example: *"What RDS reference should I use for a RAN deployment on OpenShift 4.20?"*

**Interpretation:**

- **validated: true** and a **reference** string → Use this reference for comparisons. If validation later shows diffs, the cluster is not fully aligned.
- **validated: false** or error → Version not supported, image not found, or registry/auth issue; resolve before using for alignment checks.

---

## 3. Comparing Against a Custom or HTTP Reference

**Purpose:** Check alignment with a reference that is not resolved via RDS (e.g., your own `metadata.yaml` hosted via HTTP or in a container image).

**How to check:**

1. Call **kube_compare_cluster_diff** with:
   - **reference**: HTTP/HTTPS URL to `metadata.yaml`, or container reference `container://image:tag:/path/to/metadata.yaml`.
   - **output_format** (optional): `json`, `yaml`, or `junit`.
   - **all_resources** (optional): `true` to compare all resources of types in the reference.
   - **kubeconfig** and **context** (optional): for the cluster to compare.
2. Interpret the returned comparison (see [Understanding comparison output](#understanding-comparison-output)).

**Example prompts:**

- Example: *"Compare my cluster against the reference at <https://example.com/telco-core/metadata.yaml>"*
- Example: *"Run kube-compare using reference container://quay.io/openshift-kni/telco-core-rds-rhel9:v4.18:/metadata.yaml"*

**Interpretation:**

- Same as for **kube_compare_validate_rds**: no diffs/missing → aligned; presence of diffs or missing resources → misalignment to investigate.

---

## 4. Understanding Comparison Output

When the cluster is **not** aligned to the reference, the tool returns a structured result. Use it to identify and fix issues.

### Summary

- **NumDiffCRs**: Number of cluster resources that differ from the reference.
- **NumMissing**: Number of resources present in the reference but missing in the cluster.
- **UnmatchedCRS**: Cluster resources that could not be matched to any reference template (extra or unexpected).
- **ValidationIssues**: Other validation problems (if any).

**Interpretation:**

- **NumDiffCRs > 0** → One or more resources exist in both reference and cluster but have different specs (e.g., env vars, image, replicas, tolerations). Treat as **configuration drift**.
- **NumMissing > 0** → The cluster is missing resources that the reference expects. Treat as **incomplete or wrong deployment**.
- **UnmatchedCRS** non-empty → Cluster has resources of types covered by the reference that don’t match any template (e.g., different name or namespace). May indicate customization or deviation.

### Diffs

Each entry in **Diffs** typically includes:

- **CRName**: Resource identifier (e.g. `apps/v1_Deployment_default_my-app`).
- **CorrelatedTemplate**: Reference file that was compared (e.g. `deployment.yaml`).
- **DiffOutput**: Unified diff (`--- reference`, `+++ cluster`) showing exact field differences.

**Interpretation:**

- **DiffOutput** lines prefixed with `-` are from the reference; lines prefixed with `+` are from the cluster. Use these to decide whether to change the cluster to match the reference or to update the reference if the cluster is intentionally different.

### Output Formats

- **json** / **yaml**: Best for inspection and scripting; use **Summary** for a quick pass and **Diffs** for detailed fixes.
- **junit**: Use in CI/CD to fail a job when **NumDiffCRs** or **NumMissing** is greater than zero (or when **ValidationIssues** is non-empty).

---

## 5. Typical Workflow: Identifying and Fixing Misalignment

1. **Run validation**  
   Use **kube_compare_validate_rds** with the appropriate **rds_type** (`core` or `ran`) for the cluster you want to check.

2. **Check the summary**  
   If **NumDiffCRs**, **NumMissing**, or **UnmatchedCRS** indicate issues, the cluster is not fully aligned.

3. **Inspect diffs**  
   For each item in **Diffs**, read **CRName** and **DiffOutput** to see which fields differ (e.g. image, resource requests, node selectors, tolerations).

4. Decide remediation  
   - To align with the reference: apply the reference configuration (e.g. re-apply CRs, update Deployments/Operators) so that the cluster state matches the reference.  
   - If the drift is intentional: document it and optionally adjust your reference or skip those resources in automation.

5. **Re-run validation**  
   After changes, run **kube_compare_validate_rds** again to confirm alignment.

6. **Optional: automate**  
   Use **kube_compare_cluster_diff** or **kube_compare_validate_rds** with **output_format**: `junit` in a pipeline to block promotions or flag drift in GitOps/CI.

---

## 6. Connecting to the Cluster

- **In-cluster (e.g. OpenShift Lightspeed):** No kubeconfig needed; the MCP server uses the in-cluster config and the cluster it runs in.
- **Remote cluster:** Provide **kubeconfig** (raw YAML or base64) and optionally **context**. For OLS and size limits, use a [minimal kubeconfig](https://github.com/sakhoury/kube-compare-mcp#minimal-kubeconfig-for-ols) (token-based, single context, no large CA bundles).
- **Registry (RDS):** For **kube_compare_resolve_rds** and **kube_compare_validate_rds**, the server must be able to pull from `registry.redhat.io`. On OpenShift, ensure registry credentials (e.g. pull secret) are configured for the MCP server namespace (e.g. `kube-compare-mcp`).

---

## 7. Common Causes of Misalignment

| Symptom | Possible cause | Action |
|--------|-----------------|--------|
| **NumMissing > 0** | Operators or CRs not installed or not created as in the reference. | Install missing operators; create CRs from the reference. |
| **NumDiffCRs > 0** | Cluster resources were customized (images, resources, env, node placement). | Align YAML with reference or document intentional overrides. |
| **UnmatchedCRS** | Different names/namespaces or extra resources. | Map to reference templates or exclude from comparison if intentional. |
| **Wrong RDS version** | Cluster OpenShift version doesn’t match the RDS you had in mind. | Use **kube_compare_resolve_rds** to confirm the correct reference for your OCP version. |
| **Validation/resolve failure** | Registry auth or network. | Configure registry credentials and network access for the MCP server. |

---

## Related Resources

- [kube-compare](https://github.com/openshift/kube-compare) – Upstream comparison tool.
- [kube-compare-mcp](https://github.com/sakhoury/kube-compare-mcp) – MCP server, deployment, and options (transport, registry, minimal kubeconfig).
- [OpenShift Lightspeed](https://docs.openshift.com/container-platform/latest/lightspeed/index.html) – AI assistant integration.
