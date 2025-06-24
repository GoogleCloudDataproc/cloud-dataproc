#!/bin/bash
#
# Creates the shared, persistent Secure Web Proxy (SWP) instance.
# This script is idempotent and can be re-run safely.

set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/../lib/common.sh"
load_config

function main() {
  header "Onboarding: Setting up Secure Web Proxy Infrastructure"

  # 1. Define resource names from the config file.
  local swp_instance_name="${CONFIG[SWP_INSTANCE_NAME]}"
  local network_name="${CONFIG[GCE_STANDARD_NETWORK]}"
  local region="${CONFIG[REGION]}"
  local project_id="${CONFIG[PROJECT_ID]}"
  local proxy_only_subnet_name="${network_name}-swp-proxy-only"
  local proxy_only_subnet_range="10.10.1.0/24" # Use a distinct range
  local certificate_name="${swp_instance_name}-cert"
  local security_policy_name="${swp_instance_name}-policy"

  # 2. Validate that the necessary APIs are enabled.
  validate_apis "networkservices.googleapis.com" "networksecurity.googleapis.com" "certificatemanager.googleapis.com"

  # 3. Ensure the main network exists before adding a subnet to it.
  create_network "${network_name}"

  # 4. Create a proxy-only subnet.
  if ! gcloud compute networks subnets describe "${proxy_only_subnet_name}" --region="${region}" &>/dev/null; then
    echo "Creating proxy-only subnet: ${proxy_only_subnet_name}"
    gcloud compute networks subnets create "${proxy_only_subnet_name}" \
      --purpose=REGIONAL_MANAGED_PROXY \
      --role=ACTIVE \
      --region="${region}" \
      --network="${network_name}" \
      --range="${proxy_only_subnet_range}"
  else
    echo "Proxy-only subnet '${proxy_only_subnet_name}' already exists."
  fi

  # 5. Create and upload a self-signed SSL certificate for TLS inspection.
  if ! gcloud certificate-manager certificates describe "${certificate_name}" --location="${region}" &>/dev/null; then
    echo "Creating self-signed certificate: ${certificate_name}"
    openssl req -x509 -newkey rsa:2048 -nodes \
      -keyout private.key -out certificate.crt \
      -days 365 -subj "/CN=swp.example.com"
    gcloud certificate-manager certificates create "${certificate_name}" \
      --certificate-file=certificate.crt \
      --private-key-file=private.key \
      --location="${region}"
    rm private.key certificate.crt
  else
    echo "Certificate '${certificate_name}' already exists."
  fi

  # 6. Create a Gateway Security Policy.
  if ! gcloud network-security gateway-security-policies describe "${security_policy_name}" --location="${region}" &>/dev/null; then
    echo "Creating Gateway Security Policy: ${security_policy_name}"
    gcloud network-security gateway-security-policies create "${security_policy_name}" \
      --location="${region}"
  else
    echo "Gateway Security Policy '${security_policy_name}' already exists."
  fi

  # 7. Create the Secure Web Proxy Gateway instance.
  if ! gcloud alpha network-services gateways describe "${swp_instance_name}" --location="${region}" &>/dev/null; then
    echo "Creating Secure Web Proxy Gateway: ${swp_instance_name}"
    gcloud alpha network-services gateways create "${swp_instance_name}" \
      --location="${region}" \
      --network="${network_name}" \
      --ports=443 \
      --certificate-urls="projects/${project_id}/locations/${region}/certificates/${certificate_name}" \
      --gateway-security-policy="projects/${project_id}/locations/${region}/gatewaySecurityPolicies/${security_policy_name}"
  else
    echo "Secure Web Proxy Gateway '${swp_instance_name}' already exists."
  fi

  echo "Onboarding of Secure Web Proxy infrastructure is complete."
}

main
