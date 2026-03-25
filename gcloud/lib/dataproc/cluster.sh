#!/bin/bash
#
# Dataproc Cluster Management Functions

function exists_dpgce_cluster() {
  _check_exists gcloud dataproc clusters describe "${CLUSTER_NAME}" --region="${REGION}" --project="${PROJECT_ID}" --format="json(clusterName,clusterUuid,status.selfLink,config.softwareConfig.imageVersion,config.masterConfig.imageUri)"
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
    "startup-script=gcloud config set core/universe_domain '${UNIVERSE_DOMAIN}'"
  )
  if [[ "${SWP_EGRESS}" == "true" ]]; then
    metadata_array+=(
      "http-proxy=${SWP_IP}:${SWP_PORT}"
      "https-proxy=${SWP_IP}:${SWP_PORT}"
      "proxy-uri=${SWP_IP}:${SWP_PORT}"
      "no-proxy=metadata.google.internal,${PROJECT_ID}.svc.id.goog"
      "startup-script-url=${INIT_ACTIONS_ROOT}/gce-proxy-setup.sh"
    )
  fi

  local all_metadata
  all_metadata="$(IFS='|'; echo "${metadata_array[*]}")"
  all_metadata="^|^${all_metadata}"

  local gcloud_cmd=(
    gcloud dataproc clusters create "${CLUSTER_NAME}"
    --single-node
    --master-accelerator "type=${M_ACCELERATOR_TYPE}"
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
    # NO --image or --image-version here
    --initialization-action-timeout 90m
    --optional-components "DOCKER,JUPYTER"
    --properties "spark:spark.history.fs.logDirectory=gs://${BUCKET}/phs/eventLog"
    --scopes 'https://www.googleapis.com/auth/cloud-platform,sql-admin'
  )

  if [[ "${IS_CUSTOM}" == "true" ]]; then
    if [[ -z "${CUSTOM_IMAGE_URI}" || "${CUSTOM_IMAGE_URI}" == "null" ]]; then
      echo "ERROR: --custom flag is set but CUSTOM_IMAGE_URI is not defined in env.json" >&2
      exit 1
    fi
    gcloud_cmd+=(--image "${CUSTOM_IMAGE_URI}")
    echo "INFO: Using Custom Image URI: ${CUSTOM_IMAGE_URI}"
  else
    gcloud_cmd+=(--image-version "${IMAGE_VERSION}")
     echo "INFO: Using Image Version: ${IMAGE_VERSION}"
  fi

  if [[ "${GCLOUD_QUIET}" != "true" ]]; then
    echo
    echo "Command to be executed:"
    cmd_str=$(printf "%s " "${gcloud_cmd[@]}")
    echo "${cmd_str}" | perl -pe 's/ --/ 
  --/g'
  fi

  if time "${gcloud_cmd[@]}"; then
    report_result "Created"
    refresh_resource_state "dataprocCluster" "lib/dataproc/cluster.sh" exists_dpgce_cluster
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

function exists_dataproc_cluster_vms() {
  _check_exists gcloud compute instances list --project="${PROJECT_ID}" --filter="labels.goog-dataproc-cluster-name=${CLUSTER_NAME}" --format="json(name,zone,status)"
}
export -f exists_dataproc_cluster_vms
