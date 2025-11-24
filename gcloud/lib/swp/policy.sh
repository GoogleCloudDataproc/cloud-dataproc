#!/bin/bash

function create_gateway_security_policy() {
  local policy_name="${1:-${SWP_POLICY_NAME}}"
  local region="${2:-${REGION}}"
  local project_id="${3:-${PROJECT_ID}}"
  local rule_name="allow-all-rule"
  local policy_full_name="projects/${project_id}/locations/${region}/gatewaySecurityPolicies/${policy_name}"
  local log_file="create_swp_policy_${policy_name}.log"
  local phase_name="create_gateway_security_policy"

  if check_sentinel "${phase_name}" "done"; then
    print_status "Creating Gateway Security Policy ${policy_name}..."
    report_result "Exists"
    return 0
  fi

  print_status "Creating Gateway Security Policy ${policy_name}..."
  local policy_exists=false
  if gcloud network-security gateway-security-policies describe "${policy_name}" --location="${region}" --project="${project_id}" > /dev/null 2>&1; then
    policy_exists=true
    report_result "Exists"
  else
    policy_yaml=$(cat << EOF
name: ${policy_full_name}
description: "Allow all policy for SWP"
EOF
    )
    if echo "${policy_yaml}" | run_gcloud "${log_file}" gcloud network-security gateway-security-policies import "${policy_name}" \
      --location="${region}" --project="${project_id}" \
      --source=-
    then
      report_result "Created"
      policy_exists=true
    else
      report_result "Fail"
      return 1
    fi
  fi

  if [[ "${policy_exists}" = true ]]; then
    print_status "  Ensuring allow-all rule in ${policy_name}..."
    local rule_log_file="create_swp_policy_rule_${policy_name}.log"
    if ! gcloud network-security gateway-security-policies rules describe "${rule_name}" --gateway-security-policy="${policy_name}" --location="${region}" --project="${project_id}" > /dev/null 2>&1; then
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
        --location="${region}" --project="${project_id}" \
        --source=-
      then
        report_result "Created"
      else
        report_result "Fail"
        return 1 # Fail the whole function if rule creation fails
      fi
    else
      report_result "Exists"
    fi
    create_sentinel "${phase_name}" "done"
  fi
}
export -f create_gateway_security_policy

function delete_gateway_security_policy() {
  local policy_name="${1:-${SWP_POLICY_NAME}}"
  local region="${2:-${REGION}}"
  local project_id="${3:-${PROJECT_ID}}"
  local rule_name="allow-all-rule"
  local phase_name="create_gateway_security_policy"

  print_status "Deleting Gateway Security Policy ${policy_name}..."

  local policy_check=$(gcloud network-security gateway-security-policies list --location="${region}" --project="${project_id}" --filter="name ~ /${policy_name}$" --format="value(name)" 2>/dev/null)

  if [[ -n "${policy_check}" ]]; then
    local rule_log="delete_swp_policy_rule_${policy_name}.log"
    local policy_log="delete_swp_policy_${policy_name}.log"
    # Delete the rule first
    print_status "  Deleting rule ${rule_name}..."
    local rule_check=$(gcloud network-security gateway-security-policies rules list --gateway-security-policy="${policy_name}" --location="${region}" --project="${project_id}" --filter="name ~ /${rule_name}$" --format="value(name)" 2>/dev/null)
    if [[ -n "${rule_check}" ]]; then
      if run_gcloud "${rule_log}" gcloud network-security gateway-security-policies rules delete "${rule_name}" \
        --gateway-security-policy="${policy_name}" \
        --location="${region}" --project="${project_id}" \
        --quiet; then
        report_result "Deleted"
      else
        report_result "Fail"
      fi
    else
      report_result "Not Found"
    fi

    # Delete the policy
    print_status "  Deleting policy ${policy_name}..."
    if run_gcloud "${policy_log}" gcloud network-security gateway-security-policies delete "${policy_name}" \
      --location="${region}" --project="${project_id}" \
      --quiet; then
      report_result "Deleted"
      remove_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
    fi
  else
    report_result "Not Found"
    remove_sentinel "${phase_name}" "done"
  fi
}
export -f delete_gateway_security_policy
