# Findings - 2026-03-10

## 1. Gcloud Metadata Custom Separator

**Observation:** The script `lib/dataproc/cluster.sh` utilizes a custom separator `^|^` for the `--metadata` flag when calling `gcloud dataproc clusters create`.

**Finding:** This is a technique to supply multiple key-value pairs to the `--metadata` argument without repeating the flag. The format `^|^key1=value1|^key2=value2` allows `gcloud` to parse these correctly. This can be more concise than many `--metadata key=value` lines.

## 2. GPU Configuration Management

**Observation:** GPU-related settings such as CUDA version, driver version, and download URLs are externalized into environment variables in `lib/env.sh`. These variables are then used to populate metadata values passed to the Dataproc cluster during creation.

**Finding:** This approach allows for easy modification and testing of different GPU driver and CUDA combinations without hardcoding values within the cluster creation logic. It centralizes GPU configuration parameters.
