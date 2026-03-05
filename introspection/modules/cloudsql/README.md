# Cloud SQL Inspection Module

This module checks configurations related to Cloud SQL, particularly when used as a Hive Metastore backend for Dataproc.

## Checks Performed

These checks are only performed if `CLOUD_SQL_INSTANCE_NAME` is defined in the configuration (e.g., `env.json`).

1.  **Instance Existence:** Verifies the specified Cloud SQL instance exists.
2.  **Instance State:** Checks if the instance is in the `RUNNABLE` state.

## Configuration

Parameters can be set via environment variables directly or loaded from an `env.json` file specified by `INSPECT_ENV_CONFIG` (see main README).

**Required `env.json` keys to activate module:**

-   `CLOUD_SQL_INSTANCE_NAME`: The name of the Cloud SQL instance to check.

Optional keys for future checks:

-   `CLOUD_SQL_REGION`: The region of the Cloud SQL instance (if different from the Dataproc region).
