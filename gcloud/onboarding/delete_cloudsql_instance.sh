#!/bin/bash
#
# Tears down the shared, persistent Cloud SQL instance and its associated
# VPC Peering connection and IP range allocation.
# This script is idempotent and can be re-run safely.

set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/../lib/common.sh"
load_config

function main() {
  header "Onboarding Teardown: Deleting Shared Cloud SQL Infrastructure"

  # 1. Define resource names from the config file.
  local instance_name="${CONFIG[SHARED_SQL_INSTANCE_NAME]}"
  local network_name="${CONFIG[GCE_STANDARD_NETWORK]}"

  # 2. Delete the Cloud SQL instance first.
  # This function from common.sh is generic and works for any engine.
  delete_sql_instance "${instance_name}"

  # 3. Delete the VPC Peering connection.
  # This library function must exist in _network.sh and be idempotent.
  delete_vpc_peering_connection "${network_name}"

  # 4. Delete the reserved IP range for the peering.
  # This library function must exist in _network.sh and be idempotent.
  delete_peering_ip_allocation "${network_name}"

  echo "Teardown of Cloud SQL infrastructure is complete."
}

main

