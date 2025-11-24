#!/bin/bash
# GCR functions

function create_artifacts_repository(){
  local phase_name="create_artifacts_repository"
  if check_sentinel "${phase_name}" "done"; then
    print_status "Creating Artifact Repository ${ARTIFACT_REPOSITORY}..."
    report_result "Exists"
    return 0
  fi

  print_status "Creating Artifact Repository ${ARTIFACT_REPOSITORY}..."
  if gcloud artifacts repositories describe "${ARTIFACT_REPOSITORY}" --location="${REGION}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    report_result "Exists"
    create_sentinel "${phase_name}" "done"
  else
    local log_file="create_artifacts_repository_${ARTIFACT_REPOSITORY}.log"
    if run_gcloud "${log_file}" gcloud artifacts repositories create "${ARTIFACT_REPOSITORY}" \
      --repository-format=docker \
      --location="${REGION}" --project="${PROJECT_ID}"; then
      report_result "Created"
      create_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
      return 1
    fi
  fi
}
export -f create_artifacts_repository

function push_container_image() {
  print_status "Pushing Container Image..."
  local log_file="push_container_image.log"
  if gcloud auth print-access-token \
    --impersonate-service-account "${GSA}" \
      | run_gcloud "${log_file}" docker login \
          -u oauth2accesstoken \
          --password-stdin "https://${REGION}-docker.pgk.dev"; then
    report_result "Pass"
  else
    report_result "Fail"
  fi
}
export -f push_container_image
