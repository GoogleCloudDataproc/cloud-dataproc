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

## Dataproc Environment Reproduction Scripts

This collection of bash scripts helps create and manage Google Cloud environments to reproduce and test Google Dataproc cluster setups, particularly useful for troubleshooting issues related to startup scripts, initialization actions, and network configurations.

**Core Principles:**

*   **Declarative & Idempotent:** The `create-dpgce` script is designed to be declarative. It audits the current state of the cloud environment and only creates missing resources to reach the desired state defined by the flags and `env.json`.
*   **Audit-Driven:** The `audit-dpgce` script is the foundation, performing a comprehensive, concurrent scan of the GCP environment to populate a local SQLite database (`state.db`).
*   **Stateful Cache:** A local SQLite database (`${GCLOUD_DIR}/.state/state.db`) is used to cache the audit results and persist configuration flags between runs.
*   **Modular:** Core logic is organized into functions within the `lib/` directory.

## Supported Scenarios

These scripts are designed to deploy and manage Dataproc clusters in various configurations:

*   **Standard Dataproc on GCE:** A cluster with default network settings.
*   **Egress Control:** Options for `--nat-egress` (Cloud NAT) or `--swp-egress` (Secure Web Proxy).
*   **Custom Images:** Support for deploying clusters using pre-built custom images via the `--custom` flag.
*   **GPU-Enabled Clusters:** Facilitates testing GPU-enabled clusters, often used with custom images containing pre-installed drivers.
*   **Secure Boot Clusters:** Deployment of clusters using custom images built with Secure Boot enabled.

## Setup

1.  **Prerequisites:** Ensure you have the following tools installed:
    *   `gcloud` CLI
    *   `gsutil` (usually part of `gcloud`)
    *   `jq`: Used to parse and manipulate JSON.
    *   `sqlite3`: Used to query the state cache.
    *   `perl`: Used in some utility scripts.

2.  **Clone the repository:**
    ```bash
    git clone https://github.com/cjac/dataproc-evolution
    cd dataproc-evolution/cloud-dataproc/gcloud
    ```
    (Note: Adjust clone URL if using a different fork)

3.  **Configure Environment:**
    *   Copy the sample configuration: `cp env.json.sample env.json`
    *   Edit `env.json` with your specific Google Cloud project details, region, network ranges, custom image URI, etc.

## Main Scripts (`bin/`)

The workflow centers around these main scripts:

*   **`bin/audit-dpgce`**: Queries the live cloud environment to discover deployed resources and updates the local SQLite state cache (`${GCLOUD_DIR}/.state/state.db`). Typically called automatically by other scripts, but can be run manually to inspect the current state.

*   **`bin/create-dpgce`**: The idempotent creation script. It runs an audit, stores the provided flags (e.g., `--custom`, `--nat-egress`) in the state cache, then generates and executes a plan to create any resources that are missing to achieve the desired state. It does not delete or modify existing resources if they are already present.

*   **`bin/destroy-dpgce`**: The teardown script. It audits the environment and then de-provisions all discovered resources in a safe dependency order. Uses the state cache to know what to delete. Add `--force` to also delete GCS buckets and SWP policies/certificate authorities.

*   **`bin/recreate-cluster.sh`**: Utility script to quickly delete and recreate just the Dataproc cluster VMs. It loads the *last used* flags (`--custom`, `--nat-egress`, etc.) from the `${GCLOUD_DIR}/.state/state.db` to ensure the cluster is recreated with the same configuration. Useful for testing changes to init actions or cluster properties without tearing down the whole network.

*   **`bin/ssh-m [node-index] [command...]`**: SSHes into the master node. Without arguments, it opens a shell. With arguments, it runs the command on the master node. Defaults to the first master (`-m`). If a number is provided as the first argument, it targets that index in an HA cluster (e.g., `bash bin/ssh-m 1` for `-m-1`).

*   **`bin/scp-m [node-index] <local_path(s)>`**: Copies files or directories from your local machine to the `/tmp` directory on the master node. Similar to `ssh-m`, the first argument can be a node index for HA clusters.

### Example Usage

*   **Create Environment & Cluster with NAT:**
    ```bash
    bash bin/create-dpgce --nat-egress
    ```

*   **Create Environment & Cluster with Custom Image and NAT:**
    ```bash
    bash bin/create-dpgce --nat-egress --custom
    ```

*   **Recreate the Cluster (using last saved flags):**
    ```bash
    bash bin/recreate-cluster.sh
    ```

*   **Tear Down All Environment Infrastructure:**
    ```bash
    bash bin/destroy-dpgce
    ```

*   **Tear Down Everything, Including Persistent Resources (DANGEROUS):**
    ```bash
    bash bin/destroy-dpgce --force
    ```

*   **SSH to the master node:**
    ```bash
    bash bin/ssh-m
    ```

*   **Run a command on the master node:**
    ```bash
    bash bin/ssh-m nvidia-smi
    ```

*   **Copy a file to the master node's /tmp:**
    ```bash
    bash bin/scp-m my_script.sh
    ```

### Default Behavior

If `bin/create-dpgce` is run without any flags, it defaults to the following settings:

*   `--no-custom`: Uses the standard image version.
*   `--nat-egress`: Enables Cloud NAT for internet access.
*   `--no-swp-egress`: Secure Web Proxy is disabled.
*   A Dataproc cluster *will* be created.

### Common Flags for `create-dpgce`

*   `--custom`: Use the `CUSTOM_IMAGE_URI` from `env.json` for the cluster.
*   `--no-custom`: Use the standard `IMAGE_VERSION` from `env.json`.
*   `--nat-egress`: Ensure Cloud NAT is configured for internet egress from the standard subnet.
*   `--no-nat-egress`: Do not configure Cloud NAT.
*   `--swp-egress`: Ensure Secure Web Proxy (SWP) is configured for internet egress.
*   `--no-swp-egress`: Do not configure Secure Web Proxy.
*   `--no-create-cluster`: Set up all networking and dependencies but skip the `gcloud dataproc clusters create` command.

### Debugging

*   `DEBUG=1`: Set this environment variable before running any script to enable verbose debug output (`set -x`).
    ```bash
    DEBUG=1 bash bin/create-dpgce --nat-egress
    ```
*   Logs for each script run are stored in timestamped directories under `/tmp/dataproc-repro/`.
