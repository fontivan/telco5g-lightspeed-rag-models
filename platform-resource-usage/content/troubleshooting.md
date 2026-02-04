<!-- SPDX-License-Identifier: Apache-2.0 -->

# Platform Resource Usage Troubleshooting

This guide describes how to measure platform utilization on a running cluster, compare it to the [expected performance profile](expected-performance.md), and validate actual usage. Prometheus data comes from the Prometheus MCP. Data under `/etc`, `/proc`, or `/sys` comes from the filesystem.

**Important:** The model constructs Prometheus queries dynamically at runtime via the MCP. Queries are **not** baked into the RAG or MCP—the model uses this document and the profile to determine what data to collect and how to validate it.

The agent answers questions such as:

- **"Are there any platform CPU usage anomalies over the past hour?"**
- **"Are there any platform memory usage anomalies over the past hour?"**
- **"Does the aggregate traffic on the primary node interface exceed the engineering guidelines over the past hour?"**
- **"Does my logging rate over the past hour exceed the engineering guidelines?"**
- **"Are there any platform resource usage anomalies over the past hour?"** (combination of all checks)

---

## 1. Validating Workload Partitioning

**Purpose:** Confirm that workload partitioning is enabled.

**How to check:**

- Inspect `/etc/crio/crio.conf.d/99-workload-pinning.conf`
- If the file does not exist or is not accessible where partitioning is expected, treat as **anomaly**

---

## 2. CPU Usage Anomalies

**Purpose:** Validate CPU usage over a time window (e.g., 60 minutes) against the RAN-DU Standard profile.

**Profile limits:** Overall platform CPU < 1500 mc; platform pods < 1050 mc; host services < 250 mc; kernel threads < 200 mc; per-pod usage ≤ 20% of reserved.

**What to collect:**

- **Overall platform CPU:** Total CPU utilization of the reserved CPUs (the CPUs pinned for platform workloads). Exclude idle time. Average or rate over the requested window, expressed in millicores.
- **Platform pod CPU:** Sum of CPU usage across all containers in `openshift-*` namespaces over the window, in millicores.
- **Host services CPU:** CPU usage attributed to system and OVS slices (system.slice and ovs.slice) over the window, in millicores.
- **Kernel thread CPU:** The remainder after subtracting platform pod CPU and host services CPU from overall platform CPU. Represents kernel-mode usage on reserved CPUs.
- **Per-pod vs reserved:** For each pod in `openshift-*` namespaces, collect actual CPU usage over the window. Obtain reserved CPU from the pod spec annotation `management.workload.openshift.io/cores` (in cores; convert to millicores). Flag any pod where actual usage exceeds reserved by more than 20%.

---

## 3. Memory Usage Anomalies

**Purpose:** Validate memory usage over a time window against the profile.

**Profile limits:** Overall platform pod memory ≤ 12 GB; per-pod usage ≤ 20% of reserved.

**What to collect:**

- **Overall pod memory:** Sum of working-set memory across all containers in `openshift-*` namespaces, averaged over the requested window. Convert to GB.
- **Per-pod vs reserved:** For each pod in `openshift-*` namespaces, collect actual memory usage (working set) over the window. Obtain reserved memory from the pod spec (resource requests). Flag any pod where actual usage exceeds reserved by more than 20%.

---

## 4. OVN Network Traffic

**Purpose:** Check if aggregate traffic on the primary node interface exceeds the engineering guideline.

**Profile limit:** < 50 Mbps aggregate (receive + transmit).

**What to collect:**

- Identify the physical interface used for OVN traffic via sysfs (e.g., under `/sys/class/net/`).
- Collect the receive and transmit byte rates for that interface over the requested window.
- Sum receive and transmit rates, convert to Mbps, and compare to the 50 Mbps limit.

---

## 5. Log Forwarding Rate

**Purpose:** Check if logging rate exceeds the engineering guideline.

**Profile limit:** < 50 events/second.

**What to collect:**

- Collect the rate at which events are sent from the logging sink component over the requested window, in events per second.
- Compare to the 50 events/second limit.

---

## 6. Combined Platform Resource Anomalies

**Purpose:** Run all checks above for a single question (e.g., "Are there any platform resource usage anomalies over the past hour?").

**Process:** Execute the CPU, memory, network, and logging checks for the requested time window; validate each against the profile; report any anomalies.

---

## Summary: Data Sources and Anomaly Conditions

| Check | Primary data source | Anomaly condition |
|-------|---------------------|-------------------|
| Workload partitioning | `/etc/crio/crio.conf.d/99-workload-pinning.conf` | File missing or inaccessible where expected |
| Overall platform CPU | Prometheus (MCP) | ≥ 1500 mc |
| Platform pod CPU | Prometheus (MCP) | ≥ 1050 mc |
| Host services CPU | Prometheus (MCP) | ≥ 250 mc |
| Kernel thread CPU | Prometheus (MCP), derived | ≥ 200 mc |
| Per-pod CPU vs reserved | Prometheus (MCP) + pod specs | Actual > 20% of reserved |
| Platform pod memory | Prometheus (MCP) | > 12 GB aggregate, or per-pod > 20% of reserved |
| OVN interface traffic | Prometheus (MCP) + interface from sysfs | ≥ 50 Mbps |
| Log forwarding rate | Prometheus (MCP) | ≥ 50 events/s |

The model constructs the appropriate Prometheus queries for the cluster, time window, and reserved CPU set at runtime.
