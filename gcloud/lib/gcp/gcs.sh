#!/bin/bash
#
# GCS Bucket functions

function create_bucket () {
  local phase_name="create_bucket"
  if check_sentinel "${phase_name}" "done"; then
    print_status "Creating GCS Buckets gs://${BUCKET} & gs://${TEMP_BUCKET}..."
    report_result "Exists"
    return 0
  fi

  print_status "Creating GCS Staging Bucket gs://${BUCKET}..."
  local log_file="create_bucket_${BUCKET}.log"
  if ! gsutil ls -b "gs://${BUCKET}" > /dev/null 2>&1 ; then
    if run_gcloud "${log_file}" gsutil mb -l ${REGION} gs://${BUCKET}; then
      report_result "Created"
    else
      report_result "Fail"
      return 1
    fi
  else
    report_result "Exists"
  fi
  # Grant SA permissions on BUCKET
  print_status "  Granting Storage Admin on gs://${BUCKET}..."
  if run_gcloud "${log_file}" gsutil iam ch "serviceAccount:${GSA}:roles/storage.admin" "gs://${BUCKET}"; then
    report_result "Pass"
  else
    report_result "Fail"
  fi

  print_status "Creating GCS Temp Bucket gs://${TEMP_BUCKET}..."
  local temp_log_file="create_bucket_${TEMP_BUCKET}.log"
  if ! gsutil ls -b "gs://${TEMP_BUCKET}" > /dev/null 2>&1 ; then
     if run_gcloud "${temp_log_file}" gsutil mb -l ${REGION} gs://${TEMP_BUCKET}; then
      report_result "Created"
    else
      report_result "Fail"
      return 1
    fi
  else
    report_result "Exists"
  fi
  # Grant SA permissions on TEMP_BUCKET
  print_status "  Granting Storage Admin on gs://${TEMP_BUCKET}..."
  if run_gcloud "${temp_log_file}" gsutil iam ch "serviceAccount:${GSA}:roles/storage.admin" "gs://${TEMP_BUCKET}"; then
    report_result "Pass"
  else
    report_result "Fail"
  fi

  # Copy initialization action scripts
  if [[ -d init ]] ; then
    print_status "Copying init scripts to ${INIT_ACTIONS_ROOT}..."
    local cp_log="copy_init_scripts.log"
    if run_gcloud "${cp_log}" gsutil -m cp -r "init/*" "${INIT_ACTIONS_ROOT}/"; then
      report_result "Pass"
    else
      report_result "Fail"
    fi
  fi
  create_sentinel "${phase_name}" "done"
}

function delete_bucket () {
  print_status "Deleting GCS Bucket gs://${BUCKET}..."
  local log_file="delete_bucket_${BUCKET}.log"
  if gsutil ls -b "gs://${BUCKET}" > /dev/null 2>&1; then
    if run_gcloud "${log_file}" gsutil -m rm -r "gs://${BUCKET}"; then
      report_result "Deleted"
      remove_sentinel "create_bucket" "done"
    else
      report_result "Fail"
    fi
  else
    report_result "Not Found"
  fi
  #  gsutil -m rm -r "gs://${TEMP_BUCKET}" > /dev/null 2>&1 || true # huge cache here, not so great to lose it
}
