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
  if echo "${policy_yaml}" | run_gcloud "${log_file}" gcloud network-security gateway-security-policies import "${policy_name}" \
    --location="${region}" \
    --project="${project_id}" \
    --source=-; then
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
  if echo "${rule_yaml}" | run_gcloud "${rule_log_file}" gcloud network-security gateway-security-policies rules import "${rule_name}" \
    --gateway-security-policy="${policy_name}" \
    --location="${region}" \
    --project="${project_id}" \
    --source=-; then
    report_result "Created"
  else
    report_result "Fail"
    return 1
  fi
  export SWP_POLICY_URI_PARTIAL="${policy_full_name}"
}
export -f create_gateway_security_policy

function exists_gateway_security_policy() {
  local policy_name="${1:-${SWP_POLICY_NAME}}"
  local region="${2:-${REGION}}"
  local project_id="${3:-${PROJECT_ID}}"
  _check_exists gcloud network-security gateway-security-policies describe "${policy_name}" --location="${region}" --project="${project_id}" --format="json(name)"
}
export -f exists_gateway_security_policy

function delete_gateway_security_policy() {
  local policy_name="${1:-${SWP_POLICY_NAME}}"
  local region="${2:-${REGION}}"
  local project_id="${3:-${PROJECT_ID}}"
  local rule_name="allow-all-rule"
  print_status "Deleting Gateway Security Policy ${policy_name}..."
  local rule_log="delete_swp_policy_rule_${policy_name}.log"
  local policy_log="delete_swp_policy_${policy_name}.log"
  
  print_status "  Deleting rule ${rule_name}..."
  run_gcloud "${rule_log}" gcloud network-security gateway-security-policies rules delete "${rule_name}" \
    --gateway-security-policy="${policy_name}" \
    --location="${region}" \
    --project="${project_id}" \
    --quiet

  print_status "  Deleting policy ${policy_name}..."
  if run_gcloud "${policy_log}" gcloud network-security gateway-security-policies delete "${policy_name}" \
    --location="${region}" \
    --project="${project_id}" \
    --quiet; then
    report_result "Deleted"
  else
    report_result "Fail"
  fi
}
export -f delete_gateway_security_policy
