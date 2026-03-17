#!/bin/bash
#
# Dataproc Cluster Management Functions

function exists_dpgce_cluster() {
  _check_exists "gcloud dataproc clusters describe '${CLUSTER_NAME}' --region='${REGION}' --project='${PROJECT_ID}' --format='json(clusterName,clusterUuid,status.selfLink)'"
}
export -f exists_dpgce_cluster

function create_dpgce_cluster() {
  print_status "Creating Dataproc Cluster ${CLUSTER_NAME}..."

  local metadata_array=(
    "public_secret_name=${public_secret_name}"
    "private_secret_name=${private_secret_name}"
    "secret_project=${secret_project}"
    "secret_version=${secret_version}"
    "modulus_md5sum=${modulus_md5sum}"
    "install-gpu-agent=true"
    "gpu-driver-provider=NVIDIA"
    "cuda-version=${CUDA_VERSION}"
    "gpu-driver-version=${DRIVER_VERSION}"
    "cuda-url=https://developer.download.nvidia.com/compute/cuda/13.1.0/local_installers/cuda_13.1.0_590.44.01_linux.run"
    "gpu-driver-url=https://us.download.nvidia.com/XFree86/Linux-x86_64/590.48.01/NVIDIA-Linux-x86_64-590.48.01.run"
    "gpu-conda-env=dpgce"
    "init-actions-repo=${INIT_ACTIONS_ROOT}"
    "debug=true"
    "include-pytorch=yes"
    "enable-oslogin=TRUE"
    "dask-runtime=standalone"
    "rapids-runtime=SPARK"
    "bigtable-instance=${BIGTABLE_INSTANCE}"
    "include-gpus=1"
#    "http-proxy=${SWP_IP}:${SWP_PORT}"
#    "https-proxy=${SWP_IP}:${SWP_PORT}"
#    "proxy-uri=${SWP_IP}:${SWP_PORT}"
  )

  local all_metadata
  all_metadata="$(IFS='|'; echo "${metadata_array[*]}")"
  all_metadata="^|^${all_metadata}"

  local gcloud_cmd=(
    gcloud dataproc clusters create "${CLUSTER_NAME}"
    --single-node
#    --master-accelerator "type=${M_ACCELERATOR_TYPE}"
    --master-machine-type "${M_MACHINE_TYPE}"
    --master-boot-disk-size 600
    --master-local-ssd-interface=NVME
    --num-master-local-ssds=1
    --master-boot-disk-type pd-ssd
    --region "${REGION}"
    --zone "${ZONE}"
    --subnet "${SUBNET}"
    --no-address
    --service-account "${GSA}"
    --tags "${TAGS}"
    --bucket "${BUCKET}"
    --temp-bucket "${TEMP_BUCKET}"
    --enable-component-gateway
    --metadata "${all_metadata}"
    --no-shielded-secure-boot
    --image-version "${IMAGE_VERSION}"
    --initialization-action-timeout 90m
    --optional-components "DOCKER,JUPYTER"
    --properties "spark:spark.history.fs.logDirectory=gs://${BUCKET}/phs/eventLog"
    --scopes 'https://www.googleapis.com/auth/cloud-platform,sql-admin'
  )

  if [[ "${GCLOUD_QUIET}" != "true" ]]; then
    echo
    echo "Command to be executed:"
    cmd_str=$(printf "%s " "${gcloud_cmd[@]}")
    echo "${cmd_str}" | perl -pe 's/ --/ 
  --/g'
  fi

  if time "${gcloud_cmd[@]}"; then
    report_result "Created"
  else
    report_result "Fail"
    return 1
  fi
}
export -f create_dpgce_cluster

function delete_dpgce_cluster() {
  print_status "Deleting Dataproc Cluster ${CLUSTER_NAME}..."
  local log_file="delete_dpgce_cluster_${CLUSTER_NAME}.log"
  if run_gcloud "${log_file}" gcloud dataproc clusters delete --quiet "${CLUSTER_NAME}" --region "${REGION}"; then
    report_result "Deleted"
  else
    report_result "Fail"
  fi
}
export -f delete_dpgce_cluster
