#!/bin/bash
#
# Creates the shared, persistent Squid Proxy VM and its networking.
# This script is idempotent and can be re-run safely.

set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/../lib/common.sh"
load_config

function main() {
  header "Onboarding: Setting up Squid Proxy Infrastructure"

  # 1. Define resource names. The proxy onboarding script defines its own
  #    network names to ensure isolation and minimal configuration.
  local squid_vm_name="${CONFIG[SQUID_PROXY_VM_NAME]}"
  local external_vpc_name="cuj-external-internet-vpc"
  local proxy_internal_net="cuj-proxy-internal-network"
  local proxy_internal_subnet="cuj-proxy-internal-subnet"
  local proxy_internal_range="10.20.0.0/24"


  # 2. Create the external network (with internet access) if it doesn't exist.
  if ! gcloud compute networks describe "${external_vpc_name}" &>/dev/null; then
    echo "Creating external VPC: ${external_vpc_name}"
    gcloud compute networks create "${external_vpc_name}" \
      --subnet-mode=auto \
      --description="External VPC with internet access for CUJ proxy VMs"
  else
    echo "External VPC '${external_vpc_name}' already exists."
  fi

  # 3. Create the dedicated internal network for the proxy test environment.
  create_network "${proxy_internal_net}"
  create_subnet "${proxy_internal_net}" "${proxy_internal_subnet}" "${proxy_internal_range}" "${CONFIG[REGION]}" "false"

  # 4. Create the Squid Proxy VM if it doesn't exist.
  if ! gcloud compute instances describe "${squid_vm_name}" --zone="${CONFIG[ZONE]}" &>/dev/null; then
    echo "Creating Squid Proxy VM: ${squid_vm_name}"
    gcloud compute instances create "${squid_vm_name}" \
      --zone="${CONFIG[ZONE]}" \
      --machine-type="e2-medium" \
      --image-family="debian-12" \
      --image-project="debian-cloud" \
      --tags="${CONFIG[CUJ_TAG]},squid-proxy" \
      --network-interface="network=${proxy_internal_net},subnet=${proxy_internal_subnet},no-address" \
      --network-interface="network=${external_vpc_name}" \
      --metadata="internal_subnet_range=${proxy_internal_range}" \
      --metadata-from-file="startup-script=${SCRIPT_DIR}/install_squid.sh"
  else
    echo "Squid Proxy VM '${squid_vm_name}' already exists."
  fi

  # 5. Create a firewall rule to allow traffic from the proxy's internal subnet.
  local firewall_rule_name="${CONFIG[CUJ_TAG]}-allow-proxy-internal-ingress"
  if ! gcloud compute firewall-rules describe "${firewall_rule_name}" &>/dev/null; then
    echo "Creating firewall rule to allow access to the proxy..."
    gcloud compute firewall-rules create "${firewall_rule_name}" \
      --network="${proxy_internal_net}" \
      --allow="tcp:3128" \
      --source-ranges="${proxy_internal_range}" \
      --target-tags="squid-proxy" \
      --description="Allow internal traffic to the CUJ Squid proxy"
  else
    echo "Firewall rule '${firewall_rule_name}' already exists."
  fi

  echo "Onboarding of Squid Proxy infrastructure is complete."
  echo "NOTE: It may take a few minutes for the startup script to finish installing Squid on the VM."
}

main
