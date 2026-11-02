## Granica Admin Server

Create Network and Admin Server for AWS or GCP.

Use README.md in the respective directory for instructions.

## Subnet sizing requirements

Granica runs its data plane (Spark executors for Crunch, plus platform services) on Kubernetes, and pod-IP capacity is bounded by the IP range that pods draw from. Size that range at least to the minimum below:

| Prefix | Usable IPs | Suitability for Crunch |
| --- | --- | --- |
| `/20` | ~4,000 | **Recommended** — full fan-out, large headroom |
| `/21` | ~2,000 | Good |
| `/22` | ~1,000 | **Minimum** for a Crunch fan-out |
| `/23` and smaller | ≤500 | **Not recommended** — pods fail to get IPs and Crunch stalls or fails |

**AWS (EKS).** With the default VPC CNI (secondary-IP mode), every pod draws an IP from the subnet of the node it runs on, so capacity is bounded **per private subnet, per Availability Zone** — a node in one AZ cannot use another AZ's subnet. Granica uses **two private subnets, one per AZ** (a `/20` per AZ by default). When bringing your own VPC (`existing_private_subnet_ids`), size each private subnet per the table above (AWS reserves 5 addresses per subnet) and provide one per AZ across at least two AZs.

**GCP (GKE).** GKE uses alias IP ranges: pods draw from a **secondary pod range**, while nodes use the subnet's primary range. Size the **pod secondary range** per the table above; size the node (primary) range for peak node count and the services secondary range for the number of Kubernetes services.

**Why `/22` is the floor.** The real requirement scales with peak concurrent nodes/pods × IPs reserved per node, so large workloads need more; `/22` covers a typical fan-out with headroom. Below it, Spark executors cannot obtain pod IPs and Crunch stalls or fails — there is no pre-flight capacity check today, so the shortfall only surfaces at runtime. Prefer a larger range over working around it.
