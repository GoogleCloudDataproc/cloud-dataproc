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

## Setup

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/GoogleCloudDataproc/cloud-dataproc
    cd cloud-dataproc/gcloud
    ```

2.  **Configure Environment:**
    *   Copy the sample configuration: `cp env.json.sample env.json`
    *   Edit `env.json` with your specific Google Cloud project details, region, network ranges, etc. Key fields include:
        *   `PROJECT_ID`
        *   `REGION`
        *   `ZONE` (often derived from REGION, e.g., `us-west4-b`)
        *   `BUCKET` (for staging)
        *   `TEMP_BUCKET`
        *   Other fields as needed for your test case.

3.  **Review Script Libraries:** The core logic is now modularized into files within the `lib/` directory, categorized by function (e.g., `lib/gcp`, `lib/network`, `lib/dataproc`).

## Scripts

The main scripts are located in the `bin/` directory:

*   **`bin/create-dpgce`**: Creates a standard Dataproc on GCE cluster environment, including VPC, subnets, NAT, router, and firewall rules.
*   **`bin/create-dpgce-private`**: Creates a private Dataproc on GCE cluster environment. This setup uses a Secure Web Proxy (SWP) for controlled egress and does *not* include a Cloud NAT or default internet route.
*   **`bin/create-dpgke`**: Sets up a Dataproc on GKE environment.
*   **`bin/destroy-dpgce`**: Tears down the environment created by `bin/create-dpgce`.
*   **`bin/destroy-dpgce-private`**: Tears down the environment created by `bin/create-dpgce-private`.
*   **`bin/destroy-dpgke`**: Tears down the DPGKE environment.
*   **`bin/recreate-dpgce`**: Quickly deletes and recreates the Dataproc cluster within the existing `dpgce` environment.
*   **`bin/recreate-dpgke`**: Quickly deletes and recreates the DPGKE cluster.

### Common Flags

*   `--no-create-cluster`: Used with `create-*` scripts. Sets up all networking and dependencies but skips the final `gcloud dataproc clusters create` command. Useful for preparing an environment.
*   `--force`: Used with `destroy-*` scripts. By default, GCS buckets and versioned SWP Certificate Authority components are not deleted. Use `--force` to remove these as well.
*   `--quiet-gcloud`: Used with `create-*` scripts. Suppresses the pretty-printing of the `gcloud dataproc clusters create` command.
*   `DEBUG=1`: Set this environment variable before running any script to enable verbose debug output (e.g., `DEBUG=1 bash bin/create-dpgce`).
*   `TIMESTAMP=<number>`: Set this to a specific Unix timestamp to attempt to resume a previous `create` operation or to target specific versioned resources for deletion. If not set, a new timestamp is generated for each run.

## Customizing Cluster Creation

The parameters for the `gcloud dataproc clusters create` command are primarily defined within `lib/dataproc/cluster.sh` in the `create_dpgce_cluster` function. You can adjust machine types, accelerators, metadata, properties, and initialization actions in this function.

Numerous examples of alternative configurations and common options can be found in `docs/dataproc_cluster_examples.md`.

## Idempotency and Sentinels

The `create-*` scripts use sentinel files to track the completion of major steps. These sentinels are stored in `/tmp/dataproc-repro/${RESOURCE_SUFFIX}/sentinels/`. This allows you to re-run a `create-*` script, and it will skip steps that were already completed successfully in a previous run with the same `TIMESTAMP`.

The `destroy-*` scripts remove the corresponding sentinel files.

## Logging

All `gcloud` commands executed via the `run_gcloud` helper function have their stdout and stderr redirected to log files within the `/tmp/dataproc-repro/${RESOURCE_SUFFIX}/` directory. Check these logs for details on any failures.

## Troubleshooting

*   **"command not found"**: Ensure the `bin/` script you are running sources the necessary files from the `lib/` subdirectories.
*   **Resource Deletion Failures:** Check the logs in `/tmp/dataproc-repro/${RESOURCE_SUFFIX}/` for the specific `gcloud` error. Often, dependencies prevent deletion. Use `--force` with destroy scripts to be more aggressive.
*   **Service Account Permissions:** Cluster creation can fail if the service account doesn't have the required roles. The `create_service_account` function attempts to bind these, but errors can occur. Check the `bind_*.log` files.

## Private Cluster Networking

The `create-dpgce-private` script sets up a VPC with no default internet route. Egress is intended to be handled by the Secure Web Proxy. Nodes in this cluster should not have direct internet access.