<!-- SPDX-License-Identifier: Apache-2.0 -->

# Expected Performance Profile for Platform Resources

This document defines the expected or acceptable ranges for platform resource usage. It serves as the **profile** against which the [troubleshooting](troubleshooting.md) steps validate actual cluster metrics. Values outside these ranges are reported as anomalies.

The specifics of CPU and memory usage thresholds will be defined later. Placeholders are used where numeric or band values are pending.

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
| **Range** | *To be defined.* Acceptable band (e.g., min–max % or cores) for total CPU utilization of the reserved CPU set. |
| **Sustained usage** | *To be defined.* Threshold or window (e.g., sustained over N minutes) above or below which usage is considered anomalous. |

**Anomaly:** Overall reserved-CPU usage outside the defined range or sustained outside the acceptable band.

---

## 3. Kernel CPU Usage of Reserved CPUs

| Aspect | Expected / acceptable |
|--------|------------------------|
| **Range** | *To be defined.* Acceptable band for kernel-mode CPU usage (system time, interrupts, softirqs) on reserved CPUs. |
| **Sustained usage** | *To be defined.* Threshold or window above which kernel usage is considered anomalous. |

**Anomaly:** Kernel CPU usage on reserved CPUs outside the defined range.

---

## 4. Per-Pod CPU Usage (openshift-* on Reserved CPUs)

| Aspect | Expected / acceptable |
|--------|------------------------|
| **Scope** | Subset of pods in `openshift-*` namespaces scheduled on reserved CPUs. |
| **Range** | *To be defined.* Per-pod (or per-container) acceptable CPU usage band; may vary by component or namespace. |

**Anomaly:** A pod’s CPU usage consistently above or below the expected range for that component.

---

## 5. Pod Reserved CPU vs Actual CPU Usage

| Aspect | Expected / acceptable |
|--------|------------------------|
| **Ratio or delta** | *To be defined.* Acceptable relationship between reserved CPU (requests/limits) and actual usage (e.g., max ratio of actual to requested, or acceptable under/over utilization band). |
| **Throttling risk** | Actual usage should not be persistently far above requested/limit in a way that indicates throttling or node pressure. |
| **Over-provisioning** | *To be defined.* Threshold below which reserved vs actual is considered over-provisioned. |

**Anomaly:** Large or sustained mismatch between reserved and actual CPU outside the defined criteria.

---

## 6. Pod Memory Usage

| Aspect | Expected / acceptable |
|--------|------------------------|
| **Scope** | Pods of interest (e.g., in `openshift-*` namespaces). |
| **Range** | *To be defined.* Per-pod (or per-container) acceptable memory usage band (e.g., working set). |
| **Proximity to limit** | Usage should not persistently approach or exceed the pod’s memory limit (OOM risk). |

**Anomaly:** Memory usage outside the defined range or approaching/exceeding limit.

---

## 7. Pod Reserved Memory vs Actual Memory Usage

| Aspect | Expected / acceptable |
|--------|------------------------|
| **Ratio or delta** | *To be defined.* Acceptable relationship between reserved memory (requests/limits) and actual usage. |
| **Spikes** | *To be defined.* Acceptable spike behavior (e.g., brief peaks vs sustained high usage). |

**Anomaly:** Large or sustained mismatch between reserved and actual memory, or repeated spikes outside the defined criteria.

---

## 8. OVN/OVS Network Usage

| Aspect | Expected / acceptable |
|--------|------------------------|
| **Interface** | OVN/OVS data path interface(s) discovered from `/sys` (e.g., `/sys/class/net/` or OVS/OVN device listings). |
| **Throughput** | *To be defined.* Acceptable range for receive/transmit bytes or packets per second (or over a window). |
| **Errors / drops** | *To be defined.* Acceptable error and drop rates (e.g., per second or as a fraction of traffic). |

**Anomaly:** Throughput or error/drop rates outside the defined ranges.

---

## Summary: Profile Overview

| Resource | Expected / acceptable (summary) | Specifics |
|----------|--------------------------------|------------|
| Workload partitioning | Enabled where expected; config file present and valid | Defined above. |
| Overall CPU (reserved CPUs) | Within acceptable band | *To be defined.* |
| Kernel CPU (reserved CPUs) | Within acceptable band | *To be defined.* |
| Per-pod CPU (openshift-* on reserved CPUs) | Within acceptable band per component | *To be defined.* |
| Reserved vs actual CPU | Reasonable match; no throttling/over-provisioning | *To be defined.* |
| Pod memory usage | Within acceptable band; not at limit | *To be defined.* |
| Reserved vs actual memory | Reasonable match; no OOM risk | *To be defined.* |
| OVN/OVS network | Throughput and error/drop rates within band | *To be defined.* |

When CPU and memory thresholds are defined, update this document with the concrete values or bands. The troubleshooting agent will use this profile to compare actual usage and report anomalies.
