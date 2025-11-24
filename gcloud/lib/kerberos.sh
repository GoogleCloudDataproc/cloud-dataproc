#!/bin/bash
# Kerberos functions

function create_kdc_server() {
  local phase_name="create_kdc_server"
  if check_sentinel "${phase_name}" "done"; then
    print_status "Creating KDC Server ${KDC_NAME}..."
    report_result "Exists"
    return 0
  fi

  print_status "Creating KDC Server ${KDC_NAME}..."
  if gcloud compute instances describe "${KDC_NAME}" --zone "${ZONE}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    report_result "Exists"
    create_sentinel "${phase_name}" "done"
  else
    local log_file="create_kdc_server_${KDC_NAME}.log"
    local METADATA="kdc-root-passwd=${INIT_ACTIONS_ROOT}/${KDC_ROOT_PASSWD_KEY}.encrypted"
    METADATA="${METADATA},kms-keyring=${KMS_KEYRING}"
    METADATA="${METADATA},kdc-root-passwd-key=${KDC_ROOT_PASSWD_KEY}"
    METADATA="${METADATA},startup-script-url=${INIT_ACTIONS_ROOT}/kdc-server.sh"
    METADATA="${METADATA},service-account-user=${GSA}"
    if run_gcloud "${log_file}" gcloud compute instances create "${KDC_NAME}" \
      --zone "${ZONE}" \
      --subnet "${SUBNET}" \
      --service-account="${GSA}" \
      --boot-disk-type pd-ssd \
      --image-family="${KDC_IMAGE_FAMILY}" \
      --image-project="${KDC_IMAGE_PROJECT}" \
      --machine-type="${KDC_MACHINE_TYPE}" \
      --scopes='cloud-platform' \
      --hostname="${KDC_FQDN}" \
      --metadata "${METADATA}"; then
      report_result "Created"
      create_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
      return 1
    fi
  fi
}
export -f create_kdc_server

function delete_kdc_server() {
  local phase_name="create_kdc_server"
  remove_sentinel "${phase_name}" "done"

  print_status "Deleting KDC Server ${KDC_NAME}..."
  local log_file="delete_kdc_server_${KDC_NAME}.log"
  if gcloud compute instances describe "${KDC_NAME}" --zone "${ZONE}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    if run_gcloud "${log_file}" gcloud compute instances delete "${KDC_NAME}" --zone "${ZONE}" --project="${PROJECT_ID}" --quiet; then
      report_result "Deleted"
    else
      report_result "Fail"
    fi
  else
    report_result "Not Found"
  fi
}
export -f delete_kdc_server

function create_kerberos_cluster() {
  local phase_name="create_kerberos_cluster"
  if check_sentinel "${phase_name}" "done"; then
    print_status "Creating Kerberos Cluster ${CLUSTER_NAME}..."
    report_result "Exists"
    return 0
  fi

  print_status "Creating Kerberos Cluster ${CLUSTER_NAME}..."
  if gcloud dataproc clusters describe "${CLUSTER_NAME}" --region="${REGION}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    report_result "Exists"
    create_sentinel "${phase_name}" "done"
  else
    local log_file="create_kerberos_cluster_${CLUSTER_NAME}.log"
    if run_gcloud "${log_file}" gcloud dataproc clusters create "${CLUSTER_NAME}" \
      --region "${REGION}" \
      --zone "${ZONE}" \
      --subnet "${SUBNET}" \
      --no-address \
      --service-account="${GSA}" \
      --master-machine-type n1-standard-4 \
      --master-boot-disk-type pd-ssd \
      --master-boot-disk-size 50 \
      --image-version "${IMAGE_VERSION}" \
      --bucket "${BUCKET}" \
      --initialization-action-timeout=10m \
      --max-idle="${IDLE_TIMEOUT}" \
      --enable-component-gateway \
      --scopes='cloud-platform' \
      --enable-kerberos \
      --kerberos-root-principal-password-uri="${INIT_ACTIONS_ROOT}/${KDC_ROOT_PASSWD_KEY}.encrypted" \
      --kerberos-kms-key="${KDC_ROOT_PASSWD_KEY}" \
      --kerberos-kms-key-keyring="${KMS_KEYRING}" \
      --kerberos-kms-key-location=global \
      --kerberos-kms-key-project="${PROJECT_ID}"; then
      report_result "Created"
      create_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
      return 1
    fi
  fi
}
export -f create_kerberos_cluster

function delete_kerberos_cluster() {
  local phase_name="create_kerberos_cluster"
  remove_sentinel "${phase_name}" "done"

  print_status "Deleting Kerberos Cluster ${CLUSTER_NAME}..."
  local log_file="delete_kerberos_cluster_${CLUSTER_NAME}.log"
  if gcloud dataproc clusters describe "${CLUSTER_NAME}" --region="${REGION}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    if run_gcloud "${log_file}" gcloud dataproc clusters delete --quiet --region "${REGION}" "${CLUSTER_NAME}"; then
      report_result "Deleted"
    else
      report_result "Fail"
    fi
  else
    report_result "Not Found"
  fi
}
export -f delete_kerberos_cluster