<!-- SPDX-License-Identifier: Apache-2.0 -->

# Expected Performance Profile for Platform Resources

This document defines the expected or acceptable ranges for platform resource usage. It serves as the **profile** against which the [troubleshooting](troubleshooting.md) steps validate actual cluster metrics. Values outside these ranges are reported as anomalies.

**Where is this information stored?** The profile values and methodology in this document and in [troubleshooting](troubleshooting.md) are stored in the RAG content. The model uses this content to understand thresholds and how to construct Prometheus queries dynamically via the MCP. Queries are **not** baked into the RAG or MCP—the model constructs them at runtime based on this guidance.

---

## RAN-DU Standard Profile

| Resource | Limit | Unit |
|----------|-------|------|
| Overall platform CPU usage | < 1500 | millicores (mc) |
| Overall platform pod CPU usage | < 1050 | millicores (mc) |
| Overall host services CPU usage | < 250 | millicores (mc) |
| Overall kernel thread CPU usage | < 200 | millicores (mc) |
| Per-pod platform CPU usage | ≤ 20% of reserved | ratio |
| Overall platform pod memory usage | ≤ 12 | GB |
| Per-pod memory usage | ≤ 20% of reserved | ratio |
| Aggregate OVN traffic on physical interface | < 50 | Mbps |
| Log forwarding rate | < 50 | events/second |

---

## 1. Workload Partitioning

| Aspect | Expected / acceptable |
|--------|------------------------|
| **Status** | Workload partitioning must be **enabled** on nodes where platform workloads (e.g., reserved CPUs) are expected. |
| **Configuration** | The file `/etc/crio/crio.conf.d/99-workload-pinning.conf` must exist and be readable on those nodes, with appropriate `cpu_manager_policy` and/or CPU pinning configuration. |

**Anomaly:** Workload partitioning disabled or configuration missing/inaccessible where it is expected.

---

## 2. Overall CPU Usage of Reserved CPUs

| Aspect | Expected / acceptable |
|--------|------------------------|
| **Limit** | Overall platform CPU usage < 1500 mc. |
| **Scope** | Reserved CPUs (e.g., from workload partitioning; replace with actual reserved CPU list for the cluster). |
| **Sustained usage** | Evaluate over the requested time window (e.g., 60m). |

**Anomaly:** Overall reserved-CPU usage exceeds 1500 mc.

---

## 3. Platform Pod CPU Usage

| Aspect | Expected / acceptable |
|--------|------------------------|
| **Limit** | Overall platform pod CPU usage < 1050 mc. |
| **Scope** | Pods in `openshift-*` namespaces. |

**Anomaly:** Sum of platform pod CPU usage exceeds 1050 mc.

---

## 4. Host Services CPU Usage

| Aspect | Expected / acceptable |
|--------|------------------------|
| **Limit** | Overall host services CPU usage < 250 mc. |
| **Scope** | `system.slice` and `ovs.slice` containers. |

**Anomaly:** Host services CPU usage exceeds 250 mc.

---

## 5. Kernel Thread CPU Usage

| Aspect | Expected / acceptable |
|--------|------------------------|
| **Limit** | Overall kernel thread CPU usage < 200 mc. |
| **Derivation** | Overall CPU usage − (platform pod CPU + host services CPU). |

**Anomaly:** Kernel thread CPU usage exceeds 200 mc.

---

## 6. Per-Pod CPU Usage vs Reserved

| Aspect | Expected / acceptable |
|--------|------------------------|
| **Limit** | Per-pod platform CPU usage should not exceed 20% of reserved. |
| **Reserved source** | Pod spec: `management.workload.openshift.io/cores` (in cores; convert to mc for comparison). |
| **Scope** | Platform pods in `openshift-*` namespaces. |

**Anomaly:** Any pod’s actual CPU usage exceeds 20% above its reserved value.

---

## 7. Pod Memory Usage

| Aspect | Expected / acceptable |
|--------|------------------------|
| **Limit (aggregate)** | Overall platform pod memory usage ≤ 12 GB. |
| **Limit (per-pod)** | Per-pod memory usage ≤ 20% of reserved. |
| **Scope** | Pods in `openshift-*` namespaces. |
| **Metric** | Working set (`container_memory_working_set_bytes`). |

**Anomaly:** Aggregate memory exceeds 12 GB, or any pod exceeds 20% of its reserved memory.

---

## 8. OVN/OVS Network Usage

| Aspect | Expected / acceptable |
|--------|------------------------|
| **Limit** | Aggregate traffic on the physical interface for OVN traffic < 50 Mbps. |
| **Interface discovery** | Via sysfs (e.g., `/sys/class/net/`). |
| **Scope** | Primary node interface used for OVN. |

**Anomaly:** Aggregate receive + transmit rate exceeds 50 Mbps.

---

## 9. Log Forwarding Rate

| Aspect | Expected / acceptable |
|--------|------------------------|
| **Limit** | Log forwarding rate < 50 events/second. |
| **Scope** | Vector sink component events. |

**Anomaly:** Log forwarding rate exceeds 50 events/second.

---

## Summary: Profile Overview

| Resource | Limit | Anomaly condition |
|----------|-------|-------------------|
| Workload partitioning | Enabled; config present | Missing or misconfigured |
| Overall platform CPU | < 1500 mc | Exceeds limit |
| Platform pod CPU | < 1050 mc | Exceeds limit |
| Host services CPU | < 250 mc | Exceeds limit |
| Kernel thread CPU | < 200 mc | Exceeds limit |
| Per-pod CPU vs reserved | ≤ 20% of reserved | Exceeds 20% |
| Platform pod memory (aggregate) | ≤ 12 GB | Exceeds limit |
| Per-pod memory vs reserved | ≤ 20% of reserved | Exceeds 20% |
| OVN interface traffic | < 50 Mbps | Exceeds limit |
| Log forwarding rate | < 50 events/s | Exceeds limit |

The troubleshooting agent uses this profile to compare actual usage (obtained via Prometheus MCP) and report anomalies. The model constructs the appropriate Prometheus queries at runtime based on the methodology in [troubleshooting](troubleshooting.md).
