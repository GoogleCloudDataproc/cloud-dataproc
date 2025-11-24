#!/bin/bash

function create_swp_gateway() {
  local swp_instance_name="${1:-${SWP_INSTANCE_NAME}}"
  local region="${2:-${REGION}}"
  local network_name="${3:-${NETWORK}}"
  local client_subnet_name="${4:-${PRIVATE_SUBNET}}"
  local certificate_url="${5:-${SWP_CERT_URI_PARTIAL}}"
  local gateway_security_policy_url="${6:-${SWP_POLICY_URI_PARTIAL}}"
  local project_id="${7:-${PROJECT_ID}}"
  local phase_name="create_swp_gateway"

  if check_sentinel "${phase_name}" "done"; then
    print_status "Creating SWP Gateway ${swp_instance_name}..."
    report_result "Exists"
    return 0
  fi

  print_status "Creating SWP Gateway ${swp_instance_name}..."
  local log_file="create_swp_gateway_${swp_instance_name}.log"

  if gcloud network-services gateways describe "${swp_instance_name}" --location="${region}" --project="${project_id}" > /dev/null 2>&1; then
    report_result "Exists"
    create_sentinel "${phase_name}" "done"
    return 0
  fi

  local swp_address="${SWP_IP}"
  local full_network_name="projects/${project_id}/global/networks/${network_name}"
  local full_client_subnet_name="projects/${project_id}/regions/${region}/subnetworks/${client_subnet_name}"
  local swp_full_name="projects/${project_id}/locations/${region}/gateways/${swp_instance_name}"

  gateway_yaml=$(cat << EOF
name: ${swp_full_name}
type: SECURE_WEB_GATEWAY
addresses:
- ${swp_address}
ports:
- ${SWP_PORT}
certificateUrls:
- ${certificate_url}
gatewaySecurityPolicy: ${gateway_security_policy_url}
network: ${full_network_name}
subnetwork: ${full_client_subnet_name}
scope: ${swp_instance_name}-scope
routingMode: EXPLICIT_ROUTING_MODE
EOF
)
  if echo "${gateway_yaml}" | run_gcloud "${log_file}" gcloud network-services gateways import "${swp_instance_name}" \
                --source=- \
                --location="${region}" --project="${project_id}"; then
    report_result "Created"
    create_sentinel "${phase_name}" "done"
  else
    report_result "Fail"
    return 1
  fi
}
export -f create_swp_gateway

function delete_swp_gateway() {
  local swp_instance_name="${1:-${SWP_INSTANCE_NAME}}"
  local region="${2:-${REGION}}"
  local phase_name="create_swp_gateway"

  print_status "Deleting SWP Gateway ${swp_instance_name}..."
  if gcloud network-services gateways describe "${swp_instance_name}" --location="${region}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    local log_file="delete_swp_gateway_${swp_instance_name}.log"
    if run_gcloud "${log_file}" gcloud network-services gateways delete "${swp_instance_name}" --location="${region}" --project="${PROJECT_ID}" --quiet; then
      report_result "Deleted"
      remove_sentinel "${phase_name}" "done"

      # Attempt to delete the autogen router
      local autogen_router_prefix="swg-autogen-router-"
      local autogen_routers=$(gcloud compute routers list --regions="${region}" --project="${PROJECT_ID}" --filter="network ~ /${NETWORK}$ AND name ~ ^${autogen_router_prefix}" --format="value(name)" 2>/dev/null || true)
      if [[ -n "${autogen_routers}" ]]; then
        while read -r router_name; do
          print_status "  Deleting Autogen Router ${router_name}..."
          local delete_router_log="delete_autogen_router_${router_name}.log"
          if run_gcloud "${delete_router_log}" gcloud compute routers delete "${router_name}" --region="${region}" --project="${PROJECT_ID}" --quiet; then
            report_result "Deleted"
          else
            report_result "Fail"
          fi
        done <<< "${autogen_routers}"
      fi
    else
      report_result "Fail"
    fi
  else
    report_result "Not Found"
    remove_sentinel "${phase_name}" "done"
  fi
}
export -f delete_swp_gateway