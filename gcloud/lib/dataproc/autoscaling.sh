#!/bin/bash
#
# Dataproc Autoscaling Policy functions

function create_autoscaling_policy() {
  local phase_name="create_autoscaling_policy"
  if check_sentinel "${phase_name}" "done"; then
    print_status "Creating Autoscaling Policy ${AUTOSCALING_POLICY_NAME}..."
    report_result "Exists"
    return 0
  fi

  print_status "Creating Autoscaling Policy ${AUTOSCALING_POLICY_NAME}..."
  local log_file="create_autoscaling_${AUTOSCALING_POLICY_NAME}.log"
  if gcloud dataproc autoscaling-policies describe ${AUTOSCALING_POLICY_NAME} --region ${REGION} > /dev/null 2>&1; then
    report_result "Exists"
    create_sentinel "${phase_name}" "done"
  else
    if run_gcloud "${log_file}" gcloud dataproc autoscaling-policies import ${AUTOSCALING_POLICY_NAME} --region ${REGION} --source autoscaling-policy.yaml; then
      report_result "Created"
      create_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
      return 1
    fi
  fi
}
export -f create_autoscaling_policy

function delete_autoscaling_policy() {
  local phase_name="create_autoscaling_policy"
  remove_sentinel "${phase_name}" "done"

  print_status "Deleting Autoscaling Policy ${AUTOSCALING_POLICY_NAME}..."
  if gcloud dataproc autoscaling-policies describe ${AUTOSCALING_POLICY_NAME} --region ${REGION} > /dev/null 2>&1; then
    local log_file="delete_autoscaling_${AUTOSCALING_POLICY_NAME}.log"
    if run_gcloud "${log_file}" gcloud dataproc autoscaling-policies delete --quiet ${AUTOSCALING_POLICY_NAME} --region ${REGION}; then
      report_result "Deleted"
    else
      report_result "Fail"
    fi
  else
    report_result "Not Found"
  fi
}
export -f delete_autoscaling_policy