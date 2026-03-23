#!/bin/bash
#
# IAM related functions

ROLES=(
  roles/dataproc.worker
  roles/dataproc.editor
  roles/dataproc.admin
  roles/bigquery.dataEditor
  roles/bigquery.dataViewer
  roles/bigquery.user
  roles/storage.admin
  roles/secretmanager.secretAccessor
  roles/compute.admin
  roles/iam.serviceAccountUser
)

function exists_service_account() {
  _check_exists gcloud iam service-accounts describe "${GSA}" --project="${PROJECT_ID}" --format="json(email,name)"
}
export -f exists_service_account

function get_service_account_bindings() {
  local tmp_policy_file="${REPRO_TMPDIR}/iam_policy.json"
  local cmd=(
    gcloud projects get-iam-policy "${PROJECT_ID}"
    --format=json
  )
  
  if ! "${cmd[@]}" > "${tmp_policy_file}" 2>/dev/null; then
    echo "null"
    rm -f "${tmp_policy_file}"
    return
  fi

  local policy=$(cat "${tmp_policy_file}")
  rm -f "${tmp_policy_file}"

  if [[ -z "${policy}" ]]; then
    echo "null"
    return
  fi

  echo "${policy}" | jq -r --arg GSA "serviceAccount:${GSA}" '[.bindings[] | select(.members[] == $GSA)]' | jq 'if length == 0 then null else . end'
}
export -f get_service_account_bindings

function check_service_account_bindings() {
  local bindings_json=$(get_service_account_bindings)
  if [[ "${bindings_json}" == "null" ]]; then
    echo "false"
    return
  fi

  for role in "${ROLES[@]}"; do
    local role_found=$(echo "${bindings_json}" | jq --arg ROLE "${role}" --arg GSA "serviceAccount:${GSA}" 'map(select(.role == $ROLE and .members[] == $GSA)) | length > 0')
    if [[ "${role_found}" != "true" ]]; then
      # echo "DEBUG: Role ${role} not found for ${GSA}" >&2
      echo "false"
      return
    fi
  done
  echo "true"
}
export -f check_service_account_bindings

function create_service_account() {
  print_status "Creating/Verifying Service Account ${GSA}..."
  local log_file="create_service_account_${SA_NAME}.log"
  local sa_exists=false

  if [[ $(exists_service_account) != "null" ]]; then
    sa_exists=true
    report_result "Exists"
  else
    local cmd=(
      gcloud iam service-accounts create "${SA_NAME}"
      --project="${PROJECT_ID}"
      --description="Service account for use with cluster ${CLUSTER_NAME}"
      --display-name="${SA_NAME}"
    )
    if ! run_gcloud "${log_file}" "${cmd[@]}"; then
      report_result "Fail"
      return 1
    fi
    report_result "Created"
    update_state "serviceAccount" "{"name": "${SA_NAME}"}" # Basic update
    sleep 10 # Allow propagation
  fi

  # Bind roles
  print_status "  Ensuring roles for ${GSA}... "
  local all_roles_bound=true
  for role in "${ROLES[@]}"; do
    local role_log="bind_roles/bind_${role//\//_}_${SA_NAME}.log"
    local cmd=(
      gcloud projects add-iam-policy-binding "${PROJECT_ID}"
      --member="serviceAccount:${GSA}"
      --role="${role}"
      --condition=None
      --quiet
    )
    if ! run_gcloud "${role_log}" "${cmd[@]}"; then
      all_roles_bound=false
    fi
  done

  # Verify bindings with retries
  local bindings_ok="false"
  local attempts=0
  while [[ "${bindings_ok}" != "true" && ${attempts} -lt 5 ]]; do
    attempts=$((attempts + 1))
    bindings_ok=$(check_service_account_bindings)
    if [[ "${bindings_ok}" != "true" ]]; then
      echo "  DEBUG: Role bindings not ready, attempt ${attempts}/5. Waiting 10s..." >&2
      sleep 10
    fi
  done
  update_state "serviceAccountBindings" "$(get_service_account_bindings)"
  update_state "serviceAccountRolesReady" "${bindings_ok}"

  if [[ "${bindings_ok}" = true ]]; then
     report_result "Pass"
  else
     report_result "Fail"
     echo "  ERROR: Failed to bind all required roles to ${GSA}" >&2
     return 1
  fi
}
export -f create_service_account

function delete_service_account() {
  print_status "Deleting Service Account ${GSA}... Element: serviceAccount"
  local log_file="delete_service_account_${SA_NAME}.log"

  if [[ $(get_state "serviceAccount") == "null" ]]; then
    report_result "Not Found"
    return 0
  fi

  # Attempt to remove common project-level bindings
  print_status "Removing IAM policy bindings for ${GSA}..."
  local bindings_json=$(get_state "serviceAccountBindings")
  if [[ "${bindings_json}" != "null" ]]; then
    mapfile -t roles_to_remove < <(echo "${bindings_json}" | jq -r '.[].role' | sort -u)
    for role in "${roles_to_remove[@]}"; do
      local role_log="unbind_roles/unbind_${role//\//_}_${SA_NAME}.log"
      local cmd=(
        gcloud projects remove-iam-policy-binding "${PROJECT_ID}"
        --role="${role}"
        --member="serviceAccount:${GSA}"
        --condition=None
        --quiet
      )
      run_gcloud "${role_log}" "${cmd[@]}" || true
    done
    report_result "Bindings removed"
  else
    report_result "No Bindings Found"
  fi

  print_status "Deleting service account ${GSA}..."
  local delete_cmd=(gcloud iam service-accounts delete --quiet "${GSA}")
  if run_gcloud "${log_file}" "${delete_cmd[@]}"; then
    report_result "Deleted"
    update_state "serviceAccount" "null"
    update_state "serviceAccountBindings" "null"
    update_state "serviceAccountRolesReady" "null"
  else
    report_result "Fail" # Fail the script if SA deletion fails and it wasn't a NOT_FOUND
    return 1
  fi
}
export -f delete_service_account
