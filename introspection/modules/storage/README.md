# Storage Inspection Module

This module checks for common configuration issues related to Google Cloud Storage (GCS) usage with Dataproc.

## Checks Performed

1.  **Bucket Permissions:** Verifies that the Dataproc VM Service Account has sufficient permissions on specified GCS buckets.

## Configuration

Parameters can be set via environment variables directly or loaded from an `env.json` file specified by `INSPECT_ENV_CONFIG` (see main README).

**Environment Variables / `env.json` keys:**

-   `DATAPROC_SA_EMAIL`: The email address of the service account used by the Dataproc cluster VMs.
-   `DATAPROC_GCS_BUCKETS`: A comma-separated string of GCS bucket names that the Dataproc cluster interacts with. This can be set directly, or it will be populated from `BUCKET` and `TEMP_BUCKET` if using an `env.json` file.
