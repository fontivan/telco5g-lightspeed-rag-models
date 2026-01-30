<!-- SPDX-License-Identifier: Apache-2.0 -->

# Platform Resource Usage Troubleshooting

This guide describes how to measure platform utilization on a running cluster, compare it to a known baseline, and validate actual usage against an expected profile. The **Prometheus MCP** developed as part of this feature should be leveraged for all Prometheus data. For information on files under **`/etc`**, **`/proc`**, or **`/sys`**, use the **`openshift-filesystem-mcp`** server.

The agent answers questions such as:

- Example: **"Are there currently any platform resource usage anomalies in this cluster?"**
- Example: **"Have there been any platform resource usage anomalies in this cluster in the last 24 hours?"**

---

## 1. Validating Workload Partitioning

**Purpose:** Confirm that workload partitioning is enabled. If it is not, treat this as an **immediate red flag**.

**How to check:**

- Use the **`openshift-filesystem-mcp`** server to inspect the CRI-O configuration file: **`/etc/crio/crio.conf.d/99-workload-pinning.conf`**
- If the file does not exist or is not accessible (e.g., on control-plane or non-partitioned nodes), workload partitioning may not be in effect or the node may not be configured for it.
- On nodes where workload partitioning is expected (e.g., workers running platform workloads), this file should exist and contain the appropriate `cpu_manager_policy` and/or CPU pinning configuration.

**Interpretation:**

- File present and correctly configured → workload partitioning is enabled.
- File missing or unreadable where it is expected → **anomaly**; investigate node configuration and cluster workload partitioning setup.

---

## 2. Overall CPU Usage of Reserved CPUs

**Purpose:** Measure total CPU utilization of the CPUs reserved for platform workloads.

**Data source:** Prometheus metrics (via the Prometheus MCP).

**What to collect:**

- Metrics that report CPU usage for the reserved CPU set (e.g., usage of the isolated/pinned CPUs used by the platform).
- Compare the current value (and optionally a rolling window) to the baseline or profile range.

**Interpretation:**

- Usage within the profile’s expected range → normal.
- Sustained usage above (or below) the profile’s acceptable range → **anomaly**; investigate which workloads or system processes are driving the usage.

---

## 3. Kernel CPU Usage of Reserved CPUs

**Purpose:** Account for CPU consumed by the kernel on reserved CPUs (interrupts, kernel threads, and other kernel work).

**Data source:** Prometheus metrics (via the Prometheus MCP).

**What to collect:**

- Kernel-mode CPU usage (e.g., system time, interrupts, softirqs) attributed to the reserved CPUs.
- This complements overall CPU usage by showing how much of the reserved capacity is used by the kernel rather than user-space pods.

**Interpretation:**

- Kernel usage within the profile’s expected range → normal.
- Kernel usage above the expected range → **anomaly**; consider interrupt load, kernel threads, or tuning (e.g., IRQ affinity, kernel parameters).

---

## 4. CPU Usage of Pods on Reserved CPUs

**Purpose:** Break down CPU consumption by pod for workloads that run on the reserved CPUs.

**Data source:** Prometheus metrics (via the Prometheus MCP).

**Scope:**

- Focus on a **subset of pods in the `openshift-*` namespaces** that are scheduled on the reserved CPUs (e.g., platform components, operators, DaemonSets).

**What to collect:**

- Per-pod CPU usage (e.g., `container_cpu_usage_seconds_total` or equivalent) for containers in those namespaces, filtered by nodes/labels that correspond to reserved CPUs.

**Interpretation:**

- Compare each pod’s usage to the profile and to its requested/limit values. Pods consistently over or under the expected range → **anomaly**; review pod sizing and placement.

---

## 5. Pod Reserved CPU vs Actual CPU Usage

**Purpose:** Compare how much CPU each pod has reserved (requests/limits) to how much it actually uses.

**Data sources:**

- **Reserved CPU:** Pod spec (e.g., `resources.requests.cpu`, `resources.limits.cpu`) — obtain from the cluster API or `oc get pod -o yaml`.
- **Actual CPU usage:** Prometheus metrics (via the Prometheus MCP), e.g., `container_cpu_usage_seconds_total` (or equivalent) per container.

**What to do:**

- For the relevant pods (e.g., in `openshift-*` namespaces on reserved CPUs), align reserved CPU from the pod spec with actual usage from Prometheus.
- Compare actual usage to the profile’s acceptable range and to requested/limit values.

**Interpretation:**

- Actual usage within profile range and reasonable vs reserved → normal.
- Actual usage far above reserved (risk of throttling or node pressure) or persistently far below reserved (over-provisioning) → **anomaly**; adjust requests/limits or investigate workload behavior.

---

## 6. Memory Usage of Pods

**Purpose:** Measure current memory consumption of platform pods.

**Data source:** Prometheus metrics (via the Prometheus MCP).

**What to collect:**

- Per-container or per-pod memory usage (e.g., `container_memory_working_set_bytes` or equivalent) for the pods of interest (e.g., in `openshift-*` namespaces).

**Interpretation:**

- Usage within the profile’s expected range → normal.
- Usage above the expected range or approaching limit → **anomaly**; risk of OOMKills or node memory pressure; review limits and workload behavior.

---

## 7. Pod Reserved Memory vs Actual Memory Usage

**Purpose:** Compare reserved memory (requests/limits) to actual usage.

**Data sources:**

- **Reserved memory:** Pod spec (`resources.requests.memory`, `resources.limits.memory`) — from cluster API or `oc get pod -o yaml`.
- **Actual memory usage:** Prometheus metrics (via the Prometheus MCP).

**What to do:**

- For the same subset of pods, align reserved memory from the pod spec with actual usage from Prometheus.
- Compare actual usage to the profile and to requested/limit values.

**Interpretation:**

- Actual within profile range and reasonable vs reserved → normal.
- Actual close to or above limit, or repeatedly spiking → **anomaly**; adjust requests/limits or investigate memory growth (leaks, caches).

---

## 8. Network Usage of OVN/OVS Interface

**Purpose:** Monitor network utilization on the OVN/OVS data path used by the cluster.

**Data sources:**

- **Interface name:** Use the **`openshift-filesystem-mcp`** server to discover the OVN/OVS interface from the node’s **`/sys`** hierarchy (e.g., under `/sys/class/net/` or related OVS/OVN device or port listings). The exact path may depend on the OVN-Kubernetes/OVS deployment (e.g., bridge names, OVS ports).
- **Usage (bytes/packets, errors, drops):** Prometheus metrics (via the Prometheus MCP) that expose per-interface counters (e.g., receive/transmit bytes and packets, errors, drops) for that interface.

**What to do:**

- Use **`openshift-filesystem-mcp`** to resolve the OVN/OVS interface name(s) from `/sys` (or from node/OVS configuration).
- Query Prometheus for the corresponding interface metrics and compare to the profile’s expected range.

**Interpretation:**

- Throughput and error/drop rates within the profile → normal.
- Throughput or error/drop rates outside the expected range → **anomaly**; investigate network policy, workload traffic, or NIC/node issues.

---

## 9. Validating Against a Profile and Reporting Anomalies

**Purpose:** Ensure the agent does not only collect data but also validates it against a defined baseline.

**Profile contents:**

- A **profile** defines expected or acceptable ranges (e.g., min/max or bands) for:
  - Workload partitioning (enabled/disabled and where).
  - Overall and kernel CPU usage on reserved CPUs.
  - Per-pod CPU and memory usage (and optionally reserved vs actual).
  - OVN/OVS interface throughput and error/drop rates.
- The profile may be derived from a known-good baseline (e.g., a reference cluster or a time window).

**Process:**

1. Collect the data described in sections 1–8 (workload partitioning config via **`openshift-filesystem-mcp`** for `/etc`, Prometheus metrics, pod specs, interface name from `/sys` via **`openshift-filesystem-mcp`**).
2. For each metric or check, compare the current value (and, for “last 24 hours” questions, values over the last 24 hours) to the profile’s range.
3. Flag any metric or check that falls **outside** the acceptable range as an **anomaly**.
4. Report a summary: e.g., “No current anomalies” or “Current anomalies: [list]”; for 24-hour questions, “No anomalies in the last 24 hours” or “Anomalies in the last 24 hours: [list].”

**Answering the agent questions:**

- **"Are there currently any platform resource usage anomalies in this cluster?"**  
  Run the checks above with **current** (or very recent) data; validate against the profile; answer yes/no and list any current anomalies.

- **"Have there been any platform resource usage anomalies in this cluster in the last 24 hours?"**  
  Run the same checks using data over the **last 24 hours** (e.g., Prometheus range queries, or stored results); validate against the profile; answer yes/no and list any anomalies observed in that window.

---

## Summary: Data Sources and Red Flags

| Check | Primary data source | Red flag / anomaly condition |
|-------|---------------------|------------------------------|
| Workload partitioning | `openshift-filesystem-mcp` → `/etc/crio/crio.conf.d/99-workload-pinning.conf` | File missing or inaccessible where partitioning is expected |
| Overall CPU (reserved CPUs) | Prometheus (MCP) | Outside profile range |
| Kernel CPU (reserved CPUs) | Prometheus (MCP) | Outside profile range |
| Per-pod CPU (openshift-* on reserved CPUs) | Prometheus (MCP) | Outside profile range |
| Reserved vs actual CPU | Pod specs + Prometheus (MCP) | Large mismatch or outside profile |
| Pod memory usage | Prometheus (MCP) | Outside profile range |
| Reserved vs actual memory | Pod specs + Prometheus (MCP) | Large mismatch or outside profile |
| OVN/OVS network usage | Interface from `openshift-filesystem-mcp` → `/sys`, usage from Prometheus (MCP) | Outside profile range |

Use the **Prometheus MCP** for all Prometheus queries so that the agent has a single, consistent way to fetch current and historical metrics for these steps. Use the **`openshift-filesystem-mcp`** server for all file-system data under **`/etc`**, **`/proc`**, or **`/sys`** (e.g., workload partitioning config, OVN/OVS interface discovery).
