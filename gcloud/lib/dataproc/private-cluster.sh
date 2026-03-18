#!/bin/bash
#
# Dataproc Private Cluster Management Functions

source "${GCLOUD_DIR}/lib/dataproc/cluster.sh" # Source the base cluster functions to reuse exists_dpgce_cluster

function create_dpgce_private_cluster() {
  print_status "Creating Private Dataproc Cluster ${CLUSTER_NAME}..."

  # Load CUSTOM_IMAGE_URI from env.json
  CUSTOM_IMAGE_URI=$(jq -r .CUSTOM_IMAGE_URI env.json)
  if [[ -z "${CUSTOM_IMAGE_URI}" || "${CUSTOM_IMAGE_URI}" == "null" ]]; then
    echo "ERROR: CUSTOM_IMAGE_URI is not set in env.json" >&2
    return 1
  fi

  local metadata_array=(
    "public_secret_name=${public_secret_name}"
    "private_secret_name=${private_secret_name}"
    "secret_project=${secret_project}"
    "secret_version=${secret_version}"
    "modulus_md5sum=${modulus_md5sum}"
    "install-gpu-agent=true"
    "gpu-driver-provider=NVIDIA"
    "gpu-conda-env=dpgce"
    "init-actions-repo=${INIT_ACTIONS_ROOT}"
    "debug=true"
    "include-pytorch=yes"
    "enable-oslogin=TRUE"
    "nfs-kerberos-users=ext_cjac_google_com,ext_dgodhia_google_com"
    "http-proxy=${SWP_IP}:${SWP_PORT}"
    "https-proxy=${SWP_IP}:${SWP_PORT}"
    "proxy-uri=${SWP_IP}:${SWP_PORT}"
    "dask-runtime=standalone"
    "rapids-runtime=SPARK"
    "bigtable-instance=${BIGTABLE_INSTANCE}"
    "include-gpus=1"
  )

  local all_metadata
  all_metadata="$(IFS='|'; echo "${metadata_array[*]}")"
  # Prefix with ^|^ to tell gcloud about the new separator
  all_metadata="^|^${all_metadata}"

  local gcloud_cmd=(
    gcloud dataproc clusters create "${CLUSTER_NAME}"
    --single-node
    --region "${REGION}"
    --zone "${ZONE}"
    --subnet "${PRIVATE_SUBNET}"
    --no-address
    --service-account="${GSA}"
    --tags "${TAGS}"
    --bucket "${BUCKET}"
    --temp-bucket "${TEMP_BUCKET}"
    --enable-component-gateway
    --metadata "${all_metadata}"
    --shielded-secure-boot
    --image "${CUSTOM_IMAGE_URI}"
    --initialization-action-timeout=90m
    --optional-components DOCKER,JUPYTER
    --max-idle="${IDLE_TIMEOUT}"
    --properties "spark:spark.history.fs.logDirectory=gs://${BUCKET}/phs/eventLog"
    --scopes 'https://www.googleapis.com/auth/cloud-platform,sql-admin'
  )

  # Add machine type and accelerator flags
  if [[ -n "${M_MACHINE_TYPE}" ]]; then
    gcloud_cmd+=(--master-machine-type "${M_MACHINE_TYPE}")
  fi
  if [[ -n "${M_ACCELERATOR_TYPE}" ]]; then
    gcloud_cmd+=(--master-accelerator "type=${M_ACCELERATOR_TYPE}")
  fi

  if [[ "${GCLOUD_QUIET}" != "true" ]]; then
    echo
    echo "Command to be executed:"
    cmd_str=$(printf "%s " "${gcloud_cmd[@]}")
    echo "${cmd_str}" | perl -pe 's/ --/ 
  --/g'
  fi

  if "${gcloud_cmd[@]}"; then
    report_result "Created"
    refresh_resource_state "dataprocCluster" "lib/dataproc/cluster.sh" exists_dpgce_cluster
  else
    report_result "Fail"
    return 1
  fi
}
export -f create_dpgce_private_cluster

# The standard delete function works for private clusters as well.
# We just need to make sure we source this file in destroy-dpgce.
# We alias it here for clarity, though it's not strictly necessary.
delete_dpgce_private_cluster() {
  delete_dpgce_cluster
}
export -f delete_dpgce_private_cluster
