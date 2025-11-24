#!/bin/bash
#
# GCP Project related functions

function create_project(){
  local phase_name="create_project"
  if check_sentinel "${phase_name}" "done"; then
    print_status "Checking Project ${PROJECT_ID}..."
    report_result "Exists"
    return 0
  fi

  print_status "Checking Project ${PROJECT_ID}..."
  local log_file="create_project_${PROJECT_ID}.log"
  local PROJ_DESCRIPTION=$(gcloud projects describe ${PROJECT_ID} --format json 2>/dev/null)
  local exit_code=$?
  local project_created=false

  if [[ ${exit_code} -eq 0 && "$(echo $PROJ_DESCRIPTION | jq -r .lifecycleState)" == "ACTIVE" ]]; then
    report_result "Exists"
    project_created=true
  elif [[ ${exit_code} -eq 0 && "$(echo $PROJ_DESCRIPTION | jq -r .lifecycleState)" == "DELETE_REQUESTED" ]]; then
    print_status "Undeleting Project ${PROJECT_ID}..."
    if run_gcloud "${log_file}" gcloud projects undelete --quiet ${PROJECT_ID}; then
      report_result "Created"
      project_created=true
    else
      report_result "Fail"
      exit 1
    fi
  else
    print_status "Creating Project ${PROJECT_ID}..."
    if run_gcloud "${log_file}" gcloud projects create ${PROJECT_ID} --folder ${FOLDER_NUMBER}; then
      report_result "Created"
      project_created=true
    else
      report_result "Fail"
      exit 1
    fi
  fi

  if [[ "${project_created}" = true ]]; then
    # Billing Link
    local billing_log="billing_${PROJECT_ID}.log"
    print_status "Checking Billing for Project ${PROJECT_ID}..."
    local PRJBA=$(gcloud beta billing projects describe ${PROJECT_ID} --format json 2>/dev/null | jq -r .billingAccountName)
    if [[ -z "${PRJBA}" ]]; then
      echo -e "\n${YELLOW}ACTION REQUIRED: Link Billing Account${NC}"
      cat << EOF
Project ${PROJECT_ID} needs to be linked to billing account ${BILLING_ACCOUNT}.

Please run the following command in a separate terminal where you are authenticated as ${PRIV_USER}@${PRIV_DOMAIN}:

gcloud beta billing projects link ${PROJECT_ID} --billing-account ${BILLING_ACCOUNT}

EOF
      print_status "Press enter to continue after linking billing..."
      read
      # Recheck billing
      PRJBA=$(gcloud beta billing projects describe ${PROJECT_ID} --format json 2>/dev/null | jq -r .billingAccountName)
      if [[ -z "${PRJBA}" ]]; then
        report_result "Fail"
        exit 1
      else
        report_result "Pass"
      fi
    else
      report_result "Pass"
    fi
    create_sentinel "${phase_name}" "done"
  fi
}
export -f create_project

function delete_project() {
  local phase_name="create_project"
  print_status "Deleting Project ${PROJECT_ID}..."
  local log_file="delete_project_${PROJECT_ID}.log"

  # This function has manual steps for auth, so run_gcloud is not used for all parts.
  local active_account=$(gcloud auth list 2>/dev/null | awk '/^\*/ {print $2}')
  while [[ $active_account != "${USER}@${PRIV_DOMAIN}" ]]; do
    echo "AUTHENTICATE AS YOUR @${PRIV_DOMAIN} EMAIL ADDRESS"
    gcloud auth login ${USER}@${PRIV_DOMAIN}
    active_account=$(gcloud auth list 2>/dev/null | awk '/^\*/ {print $2}')
  done
  echo "Unlinking billing..."
  gcloud beta billing projects unlink ${PROJECT_ID} > "${REPRO_TMPDIR}/${log_file}" 2>&1

  active_account=$(gcloud auth list 2>/dev/null | awk '/^\*/ {print $2}')
  while [[ $active_account != "${USER}@${DOMAIN}" ]]; do
    echo "AUTHENTICATE AS YOUR @${DOMAIN} EMAIL ADDRESS"
    gcloud auth login ${USER}@${DOMAIN}
    active_account=$(gcloud auth list 2>/dev/null | awk '/^\*/ {print $2}')
  done

  print_status "  Deleting project ${PROJECT_ID}... "
  if gcloud projects delete --quiet ${PROJECT_ID} >> "${REPRO_TMPDIR}/${log_file}" 2>&1; then
    report_result "Deleted"
    remove_sentinel "${phase_name}" "done"
  else
    report_result "Fail"
  fi
}
export -f delete_project