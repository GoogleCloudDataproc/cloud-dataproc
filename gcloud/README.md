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

# Dataproc Critical User Journey (CUJ) Framework

This directory contains a collection of scripts that form a test framework for exercising Critical User Journeys (CUJs) on Google Cloud Dataproc. The goal of this framework is to provide a robust, maintainable, and automated way to reproduce and validate the common and complex use cases that are essential for our customers.

This framework replaces the previous monolithic scripts with a modular, scalable, and self-documenting structure designed for both interactive use and CI/CD automation.

## Framework Overview

The framework is organized into several key directories, each with a distinct purpose:

* **`onboarding/`**: Contains idempotent scripts to set up persistent, shared infrastructure that multiple CUJs might depend on. These are typically run once per project. Examples include setting up a shared Cloud SQL instance or a Squid proxy VM.

* **`cuj/`**: The heart of the framework. This directory contains the individual, self-contained CUJs, grouped by the Dataproc platform (`gce`, `gke`, `s8s`). Each CUJ represents a specific, testable customer scenario.

* **`lib/`**: A collection of modular bash script libraries (`_core.sh`, `_network.sh`, `_database.sh`, etc.). These files contain all the powerful, reusable functions for creating and managing GCP resources, forming a shared API for all `onboarding` and `cuj` scripts.

* **`ci/`**: Includes scripts specifically for CI/CD automation. The `pristine_check.sh` script is designed to enforce a clean project state before and after test runs, preventing bitrot and ensuring reproducibility.

## Getting Started

Follow these steps to configure your environment and run your first CUJ.

### 1. Prerequisites

Ensure you have the following tools installed and configured:
* `gcloud` CLI (authenticated to your Google account)
* `jq`
* A Google Cloud project with billing enabled.

### 2. Configure Your Environment

Copy the sample configuration file and edit it to match your environment.

```bash
cp gcloud/env.json.sample gcloud/env.json
vi gcloud/env.json
```

You only need to edit the universal and onboarding settings. The `load_config` function in the library will dynamically generate a `PROJECT_ID` if the default value is present.

### 3. Run Onboarding Scripts

Before running any CUJs, you must set up the shared infrastructure for your project. These scripts are idempotent and can be run multiple times safely.

```bash
# Set up the shared Cloud SQL instance with VPC Peering
bash gcloud/onboarding/create_cloudsql_instance.sh

# Set up the shared Squid Proxy VM and its networking
bash gcloud/onboarding/create_squid_proxy.sh
```

### 4. Run a Critical User Journey

Navigate to the directory of the CUJ you want to run and use its `manage.sh` script.

**Example: Running the standard GCE cluster CUJ**

```bash
# Navigate to the CUJ directory
cd gcloud/cuj/gce/standard/

# Create all resources for this CUJ
./manage.sh up

# When finished, tear down all resources for this CUJ
./manage.sh down
```

Each `manage.sh` script supports several commands:
* **`up`**: Creates all resources for the CUJ.
* **`down`**: Deletes all resources created by this CUJ.
* **`rebuild`**: Runs `down` and then `up` for a full cycle.
* **`validate`**: Checks for prerequisites, such as required APIs or shared infrastructure.

## Available CUJs

This framework includes the following initial CUJs:

* **`gce/standard`**: Creates a standard Dataproc on GCE cluster in a dedicated VPC with a Cloud NAT gateway for secure internet egress.
* **`gce/proxy-egress`**: Creates a Dataproc on GCE cluster in a private network configured to use the shared Squid proxy for all outbound internet traffic.
* **`gke/standard`**: Creates a standard Dataproc on GKE virtual cluster on a new GKE cluster.
