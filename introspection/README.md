# Dataproc Introspection Tools

This directory contains tools for inspecting and validating GCP environments,
specifically for use with Dataproc and related services.

## Prerequisites

This tool is designed to inspect GCP environments, typically set up for Dataproc. To provision a standard or private network environment matching the assumptions of these checks, you can use the scripts located in the `../gcloud/` directory (relative to this `introspection` directory), as described in `../gcloud/README.md`.

These scripts can create the VPC, subnets, service accounts, and proxy configurations that this introspection tool can then validate. It is recommended to use the same `env.json` file to configure both the provisioning scripts and this inspection tool for consistency.

## Configuration

Configuration can be provided via environment variables. Alternatively, you can use a single `env.json` file to specify most parameters.

### Using `env.json`

To use a JSON configuration file, set the `INSPECT_ENV_CONFIG` environment variable to the path of your file:

```bash
export INSPECT_ENV_CONFIG="/path/to/your/env.json"
```

The tool will load parameters from this file. Environment variables for specific settings (e.g., `GOOGLE_CLOUD_PROJECT`, `REGION`) will take precedence over values in the `env.json` file.

See `b/466590510/cloud-dataproc/gcloud/env.json.sample` for an example structure. Key fields used:

-   `PROJECT_ID`: Sets `GOOGLE_CLOUD_PROJECT`
-   `REGION`: Sets `REGION`
-   `DATAPROC_SA_EMAIL`: Sets `DATAPROC_SA_EMAIL`
-   `BUCKET`: Added to `DATAPROC_GCS_BUCKETS`
-   `TEMP_BUCKET`: Added to `DATAPROC_GCS_BUCKETS`
-   `NETWORK`: Sets `NETWORK`
-   `SUBNET`: Sets `SUBNET`

### Environment Variables

-   `INSPECT_ENV_CONFIG`: Path to an optional `env.json` configuration file.
-   `GOOGLE_CLOUD_PROJECT`: Required, the GCP Project ID.
-   `REGION`: Required, the GCP Region.
-   `INSPECT_MODULES`: Comma-separated list of modules to run (e.g., `network,iam,storage`). Defaults to all.
-   See module-specific READMEs for additional variables.

## Running

```bash
python inspect_env.py
```
