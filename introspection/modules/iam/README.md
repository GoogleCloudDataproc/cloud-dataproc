# IAM Inspection Module

This module checks IAM configurations relevant to Dataproc deployments.

**Configuration:**

Parameters can be set via environment variables directly or loaded from an `env.json` file specified by `INSPECT_ENV_CONFIG` (see main README).

**Environment Variables / `env.json` keys:**

*   `DATAPROC_SA_EMAIL`: The full email address of the service account used by the Dataproc cluster VMs (e.g., my-sa@my-project.iam.gserviceaccount.com).
