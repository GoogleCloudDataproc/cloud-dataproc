#!/bin/bash

function create_gateway_security_policy() {
  local policy_name="${1:-${SWP_POLICY_NAME}}"
  local region="${2:-${REGION}}"
  local project_id="${3:-${PROJECT_ID}}"
  local rule_name="allow-all-rule"
  local policy_full_name="projects/${project_id}/locations/${region}/gatewaySecurityPolicies/${policy_name}"
  local log_file="create_swp_policy_${policy_name}.log"
  print_status "Creating Gateway Security Policy ${policy_name}..."
  
  policy_yaml=$(cat << EOF
name: ${policy_full_name}
description: "Allow all policy for SWP"
EOF
)
  local policy_cmd=(
    gcloud network-security gateway-security-policies import "${policy_name}"
    --location="${region}"
    --project="${project_id}"
    --source=-
  )
  if echo "${policy_yaml}" | run_gcloud "${log_file}" "${policy_cmd[@]}"; then
    report_result "Created"
  else
    report_result "Fail"
    return 1
  fi

  print_status "  Ensuring allow-all rule in ${policy_name}..."
  local rule_log_file="create_swp_policy_rule_${policy_name}.log"
  rule_yaml=$(cat << EOF
name: ${policy_full_name}/rules/${rule_name}
description: "Allow all traffic"
priority: 1000
enabled: true
basicProfile: ALLOW
sessionMatcher: "host() != 'none'"
EOF
)
  local rule_cmd=(
    gcloud network-security gateway-security-policies rules import "${rule_name}"
    --gateway-security-policy="${policy_name}"
    --location="${region}"
    --project="${project_id}"
    --source=-
  )
  if echo "${rule_yaml}" | run_gcloud "${rule_log_file}" "${rule_cmd[@]}"; then
    report_result "Created"
  else
    report_result "Fail"
    return 1
  fi
  export SWP_POLICY_URI_PARTIAL="${policy_full_name}"
  refresh_resource_state "swpPolicy" "lib/swp/policy.sh" exists_gateway_security_policy "${policy_name}" "${region}" "${project_id}"
}
export -f create_gateway_security_policy

function exists_gateway_security_policy() {
  local policy_name="${1:-${SWP_POLICY_NAME}}"
  local region="${2:-${REGION}}"
  local project_id="${3:-${PROJECT_ID}}"
  _check_exists gcloud network-security gateway-security-policies describe "${policy_name}" --location="${region}" --project="${project_id}" --format=json
}
export -f exists_gateway_security_policy

function get_or_construct_swp_policy_uri() {
  local policy_json=$(get_state "swpPolicy")
  if [[ -n "${policy_json}" && "${policy_json}" != "null" ]]; then
    export SWP_POLICY_URI_PARTIAL=$(echo "${policy_json}" | /usr/bin/jq -r '.name')
  else
    export SWP_POLICY_URI_PARTIAL="projects/${PROJECT_ID}/locations/${REGION}/gatewaySecurityPolicies/${SWP_POLICY_NAME}"
  fi
}
export -f get_or_construct_swp_policy_uri

function delete_gateway_security_policy() {
  local policy_name="${1:-${SWP_POLICY_NAME}}"
  local region="${2:-${REGION}}"
  local project_id="${3:-${PROJECT_ID}}"
  local rule_name="allow-all-rule"
  print_status "Deleting Gateway Security Policy ${policy_name}..."
  local rule_log="delete_swp_policy_rule_${policy_name}.log"
  local policy_log="delete_swp_policy_${policy_name}.log"
  
  print_status "  Deleting rule ${rule_name}..."
  local del_rule_cmd=(
    gcloud network-security gateway-security-policies rules delete "${rule_name}"
    --gateway-security-policy="${policy_name}"
    --location="${region}"
    --project="${project_id}"
    --quiet
  )
  run_gcloud "${rule_log}" "${del_rule_cmd[@]}"

  print_status "  Deleting policy ${policy_name}..."
  local del_policy_cmd=(
    gcloud network-security gateway-security-policies delete "${policy_name}"
    --location="${region}"
    --project="${project_id}"
    --quiet
  )
  if run_gcloud "${policy_log}" "${del_policy_cmd[@]}"; then
    report_result "Deleted"
  else
    report_result "Fail"
  fi
}
export -f delete_gateway_security_policy
