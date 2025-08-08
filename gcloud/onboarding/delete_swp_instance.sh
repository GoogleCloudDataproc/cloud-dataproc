#!/bin/bash
#
# Tears down the shared, persistent Secure Web Proxy (SWP) instance.
# This script is idempotent and can be re-run safely.

set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/../lib/common.sh"
load_config

function main() {
  header "Onboarding Teardown: Deleting Secure Web Proxy Infrastructure"

  # 1. Define resource names from the config file.
  local swp_instance_name="${CONFIG[SWP_INSTANCE_NAME]}"
  local network_name="${CONFIG[GCE_STANDARD_NETWORK]}"
  local region="${CONFIG[REGION]}"
  local project_id="${CONFIG[PROJECT_ID]}"
  local proxy_only_subnet_name="${network_name}-swp-proxy-only"
  local certificate_name="${swp_instance_name}-cert"
  local security_policy_name="${swp_instance_name}-policy"

  # 2. Delete the Secure Web Proxy Gateway instance.
  if gcloud alpha network-services gateways describe "${swp_instance_name}" --location="${region}" &>/dev/null; then
    echo "Deleting Secure Web Proxy Gateway: ${swp_instance_name}"
    gcloud alpha network-services gateways delete "${swp_instance_name}" --location="${region}" --quiet
  else
    echo "Secure Web Proxy Gateway '${swp_instance_name}' not found."
  fi

  # 3. Delete the Gateway Security Policy.
  if gcloud network-security gateway-security-policies describe "${security_policy_name}" --location="${region}" &>/dev/null; then
    echo "Deleting Gateway Security Policy: ${security_policy_name}"
    gcloud network-security gateway-security-policies delete "${security_policy_name}" --location="${region}" --quiet
  else
    echo "Gateway Security Policy '${security_policy_name}' not found."
  fi

  # 4. Delete the SSL certificate.
  if gcloud certificate-manager certificates describe "${certificate_name}" --location="${region}" &>/dev/null; then
    echo "Deleting certificate: ${certificate_name}"
    gcloud certificate-manager certificates delete "${certificate_name}" --location="${region}" --quiet
  else
    echo "Certificate '${certificate_name}' not found."
  fi

  # 5. Delete the proxy-only subnet.
  if gcloud compute networks subnets describe "${proxy_only_subnet_name}" --region="${region}" &>/dev/null; then
    echo "Deleting proxy-only subnet: ${proxy_only_subnet_name}"
    gcloud compute networks subnets delete "${proxy_only_subnet_name}" --region="${region}" --quiet
  else
    echo "Proxy-only subnet '${proxy_only_subnet_name}' not found."
  fi

  echo "Teardown of Secure Web Proxy infrastructure is complete."
}

main
