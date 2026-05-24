<!--

Copyright 2021-2026 Google LLC and contributors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

-->

# Dataproc Environment Reproduction Scripts

This collection of bash scripts facilitates the rapid provisioning, management, and teardown of Google Cloud environments to reproduce and test Google Dataproc cluster setups. It is particularly useful for troubleshooting initialization actions, custom images, complex network topologies (like SWP and NAT), and GPU driver integrations.

**Core Principles:**

*   **Declarative & Idempotent:** The `create-dpgce` script operates declaratively. It audits the current state of the cloud environment and only creates missing resources required to reach the desired configuration state (defined by CLI flags and `env.json`).
*   **Audit-Driven:** The `audit-dpgce` (and `audit-dpgke`) script forms the foundation, performing a comprehensive, concurrent scan of your GCP project to populate a local SQLite database (`.state/state.db`).
*   **Stateful Cache:** A persistent local SQLite database (`.state/state.db`) caches audit results and persists your operational configuration flags between runs (e.g., remembering if you deployed with `--gpu` and `--custom`).
*   **Modular:** Core infrastructure logic is organized cleanly into functions within the `lib/` directory.

## Supported Scenarios

These scripts deploy Dataproc clusters in various configurations, supporting both Compute Engine (DPGCE) and Kubernetes Engine (DPGKE) architectures:

*   **Standard Dataproc on GCE (DPGCE):** Clusters with default or advanced network settings.
*   **Dataproc on GKE (DPGKE):** Provisioning of GKE clusters and registration of Dataproc virtual clusters.
*   **Egress Control:** Options for `--nat-egress` (Cloud NAT) or `--swp-egress` (Secure Web Proxy) to test isolated network environments.
*   **Custom Images & Secure Boot:** Support for deploying clusters using pre-built custom images (`--custom`) and validating Shielded VM Secure Boot constraints.
*   **GPU-Enabled Clusters:** Facilitates testing hardware accelerators (`--gpu`), integrating seamlessly with local or remote GPU initialization scripts.

## Setup & Configuration

1.  **Prerequisites:**
    *   `gcloud` CLI and `gsutil`
    *   `jq` (for JSON parsing)
    *   `sqlite3` (for state cache queries)
    *   `perl` (used in some robust text-manipulation utilities)

2.  **Configure Environment (`env.json`):**
    Copy the sample configuration file to begin:
    ```bash
    cp env.json.sample env.json
    ```
    Edit `env.json` with your specific details. Critical fields include:
    *   `PROJECT_ID`, `REGION`, `ZONE`: Your target GCP deployment topology.
    *   `IMAGE_VERSION`: The Dataproc OS/Version to test (e.g., `2.2-ubuntu22`, `2.0-rocky8`).
    *   `CUSTOM_IMAGE_URI`: The specific GCP image URI to use when deploying with `--custom`.
    *   `ACCELERATOR_TYPE`: The GPU hardware type to attach when deploying with `--gpu` (e.g., `nvidia-tesla-t4`).
    *   `BUCKET` / `TEMP_BUCKET`: Target GCS buckets for staging initialization scripts and staging large files.
    *   `RANGE`, `PRIVATE_RANGE`, `SWP_RANGE`: Subnet CIDR blocks.

## Main Lifecycle Scripts (`bin/`)

The core workflow centers around the following lifecycle management scripts. Note that scripts ending in `-dpgce` target Dataproc on Compute Engine, while `-dpgke` target Dataproc on GKE.

*   **`bin/audit-dpgce` / `bin/audit-dpgke`**: Queries the live cloud environment to discover deployed resources and updates the local SQLite state cache. Typically called automatically, but useful for manual state inspection.
*   **`bin/create-dpgce` / `bin/create-dpgke`**: The idempotent creation script. Generates a deployment plan based on missing infrastructure and creates the necessary resources (networks, routers, proxies, node pools, clusters). 
*   **`bin/destroy-dpgce` / `bin/destroy-dpgke`**: The teardown script. Audits the environment and de-provisions all discovered resources in a safe dependency order. Add `--force` to forcefully delete persistent storage (GCS buckets) and SWP policies.
*   **`bin/recreate-dpgce` / `bin/recreate-dpgke`**: Utility script to rapidly delete and recreate *only* the Dataproc cluster (or GKE node pools) while leaving the underlying network infrastructure intact. It intelligently loads the *last used flags* from `.state/state.db`.

## Utilities (`bin/`)

*   **`bin/ssh-m [node-index] [command...]`**: SSH into the -m node. Target HA -m nodes using numeric indexes (e.g., `bin/ssh-m 1` for `-m-1`).
*   **`bin/ssh-w [node-index] [command...]`**: SSH into a worker node (e.g., `bin/ssh-w 0` for `-w-0`).
*   **`bin/scp-m` / `bin/scp-w`**: Optimized file transfer to cluster nodes. These scripts bypass slow IAP TCP windowing by staging files to a GCS `TEMP_BUCKET` and invoking a remote `gcloud storage cp` pull on the node, dramatically reducing transfer times.
*   **`bin/setup-cicd.sh`**: Automates the provisioning of a Cloud Build CI/CD pipeline, connecting Cloud Source Repositories, and configuring necessary IAM service accounts for remote integration testing.

## Fast Iterative Development (Initialization Actions)

When developing or debugging complex initialization actions (like GPU drivers), destroying and recreating the entire Dataproc cluster takes too much time. Use this optimized workflow for rapid manual testing:

1.  **Provision a Bare Cluster:** Deploy the cluster with hardware attached but bypass the initialization action execution during boot.
    ```bash
    ./bin/recreate-dpgce --gpu --no-init-action
    ```
2.  **Stage Your Script:** Use the optimized `scp-m` command to transfer your local development script to the node quickly.
    ```bash
    ./bin/scp-m /path/to/your/install_gpu_driver.sh
    ```
4.  **Execute and Monitor (Robust Execution):** Instead of standard SSH, use the `install-in-screen.sh` wrapper to execute the script. This safely encapsulates the execution in a detached `screen` session. If your SSH connection drops, running the command again will instantly re-attach you without interrupting the build.
    ```bash
    cd ../initialization-actions
    ./gpu/install-in-screen.sh
    ```
5.  *(Idempotent Retries)*: If your script uses completion sentinels, purge them before testing your fix to ensure the specific phase executes again.
    ```bash
    cd ../cloud-dataproc/gcloud
    ./bin/ssh-m 'sudo rm -rf /opt/install-dpgce/complete'
    ```

## Common CLI Flags

Applicable primarily to `create-dpgce` and `recreate-dpgce`:

*   `--custom` / `--no-custom`: Toggle between the `CUSTOM_IMAGE_URI` and standard `IMAGE_VERSION` defined in `env.json`.
*   `--nat-egress` / `--no-nat-egress`: Enable/disable Cloud NAT for outbound internet access on the cluster subnet.
*   `--swp-egress` / `--no-swp-egress`: Enable/disable Secure Web Proxy (SWP) for restricted, proxied internet egress.
*   `--gpu` / `--no-gpu`: Enable/disable attachment of the `ACCELERATOR_TYPE` to the cluster nodes.
*   `--no-init-action`: Provisions the cluster but skips appending initialization action URIs to the cluster creation command.
*   `--no-create-cluster`: Sets up all underlying networking, proxies, and dependencies but skips the final `gcloud dataproc clusters create` command.

## Debugging

*   **Trace Execution:** Set `DEBUG=1` before running any script to enable verbose bash execution tracing (`set -x`).
    ```bash
    DEBUG=1 bash bin/create-dpgce --nat-egress
    ```
*   **Audit Logs:** Detailed execution logs for the scripts are stored in timestamped directories under `/tmp/dataproc-repro/`.