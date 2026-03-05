# Network Inspection Module

This module checks network configurations relevant to Dataproc deployments.

**Configuration:**

Parameters can be set via environment variables directly or loaded from an `env.json` file specified by `INSPECT_ENV_CONFIG` (see main README).

**Environment Variables / `env.json` keys:**

*   `NETWORK`: The name of the VPC network to inspect.
*   `SUBNET`: The name of the Subnet to inspect.
