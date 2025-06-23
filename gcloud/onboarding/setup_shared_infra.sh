#!/bin/bash
#
# Creates the shared, "unmanaged" infrastructure that CUJs depend on.
# This script is idempotent and can be re-run safely.

source ../lib/common.sh
load_config

function main() {
  header "Onboarding: Setting up Shared Infrastructure"

  echo "Creating shared GCS bucket: ${CONFIG[SHARED_GCS_BUCKET]}"
  # Use gsutil's 'mb' command with -p to create if it doesn't exist.
  gsutil -q mb -p "${CONFIG[PROJECT_ID]}" "gs://${CONFIG[SHARED_GCS_BUCKET]}" || echo "Bucket already exists."

  # Add other shared resource creation here in the future,
  # for example, a shared KDC virtual machine.

  echo "Onboarding of shared infrastructure complete."
}

main
