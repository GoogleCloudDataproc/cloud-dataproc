#!/bin/bash
#
# Dataproc Cluster Management Functions

function exists_dpgce_cluster() {
  # print_status "  Checking if cluster ${CLUSTER_NAME} exists..."
  if gcloud dataproc clusters describe "${CLUSTER_NAME}" --region="${REGION}" --project="${PROJECT_ID}" > /dev/null 2>&1;
 then
    # report_result "Exists"
    return 0 # Found
  else
    # report_result "Not Found"
    return 1 # Not found
  fi
}
export -f exists_dpgce_cluster

function create_dpgce_cluster() {
  local phase_name="create_dpgce_cluster"
  # Note: No sentinel check here because this is the main resource being created/recreated.
  # We rely on the --no-create-cluster flag to skip this if needed.

  print_status "Creating Dataproc Cluster ${CLUSTER_NAME}..."

  local gcloud_cmd=(
    gcloud dataproc clusters create "${CLUSTER_NAME}"
    --single-node
    --master-accelerator "type=${MASTER_ACCELERATOR_TYPE}"
    --worker-accelerator "type=${PRIMARY_ACCELERATOR_TYPE}"
    --secondary-worker-accelerator "type=${SECONDARY_ACCELERATOR_TYPE}"
    --master-machine-type "${MASTER_MACHINE_TYPE}"
    --worker-machine-type "${PRIMARY_MACHINE_TYPE}"
    --master-boot-disk-size 60
    --worker-boot-disk-size 60
    --secondary-worker-boot-disk-size 60
    --master-boot-disk-type pd-ssd
    --worker-boot-disk-type pd-ssd
    --secondary-worker-boot-disk-type pd-ssd
    --region "${REGION}"
    --zone "${ZONE}"
    --subnet "${SUBNET}"
    --no-address
    --service-account="${GSA}"
    --tags="${TAGS}"
    --bucket "${BUCKET}"
    --temp-bucket "${TEMP_BUCKET}"
    --enable-component-gateway
    --metadata "public_secret_name=${public_secret_name}"
    --metadata "private_secret_name=${private_secret_name}"
    --metadata "secret_project=${secret_project}"
    --metadata "secret_version=${secret_version}"
    --metadata "modulus_md5sum=${modulus_md5sum}"
    --metadata "install-gpu-agent=true"
    --metadata "gpu-driver-provider=NVIDIA"
    --metadata "gpu-conda-env=dpgce"
    --metadata "rapids-mirror-disk=${RAPIDS_MIRROR_DISK_NAME}"
    --metadata "rapids-mirror-host=${RAPIDS_REGIONAL_MIRROR_ADDR[${REGION}]}"
    --metadata "init-actions-repo=${INIT_ACTIONS_ROOT}"
    --metadata "dask-cloud-logging=true"
    --metadata "debug=true"
    --metadata "http-proxy=${SWP_IP}:${SWP_PORT}"
    --metadata dask-runtime="standalone"
    --metadata rapids-runtime="SPARK"
    --metadata bigtable-instance=${BIGTABLE_INSTANCE}
    --metadata include-gpus=1
    --image "projects/${PROJECT_ID}/global/images/dataproc-2-2-deb12-20251108-180659-tf" \
    --initialization-action-timeout=90m
    --optional-components DOCKER,JUPYTER
    --max-idle="${IDLE_TIMEOUT}"
    --properties "spark:spark.history.fs.logDirectory=gs://${BUCKET}/phs/eventLog"
    --scopes 'https://www.googleapis.com/auth/cloud-platform,sql-admin'
  )

#    --no-shielded-secure-boot
#    --image-version "${IMAGE_VERSION}"
#    --initialization-actions ${INIT_ACTIONS_ROOT}/gpu/install_gpu_driver.sh
#    --metadata=startup-script-url="gs://dataproc-staging-us-west4-kf7bmp/dataproc-initialization-actions/gce-proxy-setup.sh"


  if [[ "${GCLOUD_QUIET}" != "true" ]]; then
    echo
    echo "Command to be executed:"
    cmd_str=$(printf "%s " "${gcloud_cmd[@]}")
    # Replace " --" with " \\\n  --" for pretty printing
    echo "${cmd_str}" | perl -pe 's/ --/ \\\n  --/g'
  fi

  if "${gcloud_cmd[@]}"; then
    report_result "Created"
  else
    report_result "Fail"
    return 1
  fi
}
export -f create_dpgce_cluster

function delete_dpgce_cluster() {
  print_status "Deleting Dataproc Cluster ${CLUSTER_NAME}..."
  if exists_dpgce_cluster;
 then
    local log_file="delete_dpgce_cluster_${CLUSTER_NAME}.log"
    if run_gcloud "${log_file}" gcloud dataproc clusters delete --quiet --region ${REGION} ${CLUSTER_NAME}; then
      report_result "Deleted"
    else
      report_result "Fail"
    fi
  else
    report_result "Not Found"
  fi
}
export -f delete_dpgce_cluster
