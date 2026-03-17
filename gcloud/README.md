<!--

Copyright 2021 Google LLC and contributors

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
*   **State-Driven:** The scripts are driven by a single `state.json` file that acts as the authoritative source of truth for the environment.
*   **Idempotent:** The `create-dpgce` script is idempotent. It can be run on a new, partially-built, or complete environment, and it will always safely and efficiently bring the environment to the target configuration, creating only the missing resources.
*   **Modular:** Core logic is modularized into files within the `lib/` directory, categorized by function.

## Supported Scenarios

These scripts are designed to deploy and manage Dataproc clusters in various configurations:

*   **Standard Dataproc on GCE:** A cluster with default network settings and internet access via Cloud NAT.
*   **Private Dataproc on GCE:** A cluster in a private network with no direct internet access. Egress is controlled through a Secure Web Proxy (SWP).
*   **GPU-Enabled Clusters:** Configuration and testing scripts for clusters utilizing NVIDIA GPUs, including driver installation and YARN resource management.
*   **Secure Boot Clusters:** Deployment of clusters using custom images built with Secure Boot enabled.
*   **Dataproc on GKE:** Basic setup for Dataproc on Google Kubernetes Engine.

## Setup

1.  **Prerequisites:** Ensure you have the following tools installed:
    *   `gcloud` CLI
    *   `gsutil` (usually part of `gcloud`)
    *   `jq`: Used to parse and manipulate JSON responses from the `gcloud` API.
    *   `sqlite3`: Used to maintain a local cache database (`state.db`) of resource states, providing atomic and concurrent-safe updates.
    *   `perl`

2.  **Clone the repository:**
    ```bash
    git clone https://github.com/GoogleCloudDataproc/cloud-dataproc
    cd cloud-dataproc/gcloud
    ```

3.  **Configure Environment:**
    *   Copy the sample configuration: `cp env.json.sample env.json`
    *   Edit `env.json` with your specific Google Cloud project details, region, network ranges, etc.

## Main Scripts (`bin/`)

The new workflow centers around three main scripts:

*   **`bin/audit-dpgce`**: The source of truth. This script queries the live cloud environment to discover which resources are actually deployed and writes their status to `state.json`. It is called automatically by the other scripts.
*   **`bin/create-dpgce`**: The idempotent creation script. It audits the environment and then creates only the resources that are missing to bring the environment to the desired state. It supports flags like `--custom` and `--private` to control deployment variations.
*   **`bin/destroy-dpgce`**: The teardown script. It audits the environment and then de-provisions all discovered resources in the correct dependency order.

### Example Usage

*   **Create a Standard Dataproc Environment & Cluster:**
    ```bash
    bash bin/create-dpgce
    ```

*   **Create a Private & Custom Image Dataproc Environment:**
    ```bash
    bash bin/create-dpgce --private --custom
    ```

*   **Tear Down All Environment Infrastructure:**
    ```bash
    bash bin/destroy-dpgce
    ```

*   **Tear Down Everything, Including GCS Buckets:**
    ```bash
    bash bin/destroy-dpgce --force
    ```

*   **Recreate Just the Cluster (in an existing environment):**
    ```bash
    bash bin/recreate-cluster.sh
    ```

### Common Flags

*   `--custom`: Used with `create-dpgce`. Deploys a cluster using a custom image.
*   `--private`: Used with `create-dpgce`. Deploys a private cluster with a Secure Web Proxy (SWP).
*   `--no-create-cluster`: Used with `create-dpgce`. Sets up all networking and dependencies but skips the final `gcloud dataproc clusters create` command.
*   `--force`: Used with `destroy-dpgce`. By default, GCS buckets are preserved. Use `--force` to delete them as well.
*   `DEBUG=1`: Set this environment variable before running any script to enable verbose debug output.
