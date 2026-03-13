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
#    "nfs-kerberos-users=ext_cjac_google_com,ext_dgodhia_google_com"
    "dask-runtime=standalone"
    "rapids-runtime=SPARK"
    "bigtable-instance=${BIGTABLE_INSTANCE}"
    "include-gpus=1"
#    "startup-script-url=gs://dataproc-staging-us-west4-kf7bmp/dataproc-initialization-actions/gce-proxy-setup.sh"
#    "rapids-mirror-disk=${RAPIDS_MIRROR_DISK_NAME}"
#    "rapids-mirror-host=${RAPIDS_REGIONAL_MIRROR_ADDR[${REGION}]}"
#    "dask-cloud-logging=true"

#    "http-proxy=${SWP_IP}:${SWP_PORT}"
#    "https-proxy=${SWP_IP}:${SWP_PORT}"
#    "proxy-uri=${SWP_IP}:${SWP_PORT}"
#    "startup-script-url=gs://dataproc-staging-us-west4-kf7bmp/dataproc-initialization-actions/gce-proxy-setup.sh"
#    "dask-runtime=standalone"
#    "rapids-runtime=SPARK"
#    "bigtable-instance=${BIGTABLE_INSTANCE}"
#    "include-gpus=1"

  )

  local all_metadata
# Join with specified separator
#  all_metadata=$(IFS=,; echo "${metadata_array[*]}")
  all_metadata="$(IFS='|'; echo "${metadata_array[*]}")"
#  all_metadata=$(IFS='~~'; echo "${metadata_array[*]}")
  # Prefix with ^|^ to tell gcloud about the new separator
  all_metadata="^|^${all_metadata}"

  # Logic to determine whether to use a custom image, build one, or use a stock image.
  local image_args=()
  if check_image_exists "${CUSTOM_IMAGE_URI}"; then
    print_status "Found existing custom image: ${CUSTOM_IMAGE_URI}. Using it."
    image_args=("--image" "${CUSTOM_IMAGE_URI}")
  else
    # CUSTOM_IMAGE_URI from env.json does not exist.
    # Check if a sentinel file for a freshly built image exists.
    local custom_image_sentinel_file="${SENTINEL_DIR}/custom_image_uri.txt"
    if [[ -f "${custom_image_sentinel_file}" ]]; then
      local fresh_image_uri
      fresh_image_uri=$(cat "${custom_image_sentinel_file}")
      if check_image_exists "${fresh_image_uri}"; then
        print_status "Found freshly built custom image: ${fresh_image_uri}. Using it."
        image_args=("--image" "${fresh_image_uri}")
      else
        # Sentinel file points to a non-existent image, something is wrong.
        print_status "Image from sentinel file not found: ${fresh_image_uri}. Falling back to build."
        # Fall through to build logic
      fi
    fi
  fi

  # If no image has been selected, attempt to build one.
  if [[ ${#image_args[@]} -eq 0 ]]; then
    print_status "No existing custom image found. Attempting to build a new one..."
    if (cd ../../custom-images/examples/secure-boot && ./build-and-run-podman.sh); then
      local custom_image_sentinel_file="${SENTINEL_DIR}/custom_image_uri.txt"
      if [[ -f "${custom_image_sentinel_file}" ]]; then
        local fresh_image_uri
        fresh_image_uri=$(cat "${custom_image_sentinel_file}")
        print_status "Successfully built new image: ${fresh_image_uri}. Using it."
        image_args=("--image" "${fresh_image_uri}")
      else
        print_status "Build script ran, but sentinel file not found. Falling back to stock image version."
        image_args=("--image-version" "${IMAGE_VERSION}")
      fi
    else
      print_status "Failed to build custom image. Falling back to stock image version."
      image_args=("--image-version" "${IMAGE_VERSION}")
    fi
  fi

  local gcloud_cmd=(
    gcloud dataproc clusters create "${CLUSTER_NAME}"
    --single-node
#    --num-masters=1
#    --num-workers=2
    --master-accelerator "type=${M_ACCELERATOR_TYPE}"
  #  --worker-accelerator "type=${PRIMARY_ACCELERATOR_TYPE}"
  #  --secondary-worker-accelerator "type=${SECONDARY_ACCELERATOR_TYPE}"
    --master-machine-type "${M_MACHINE_TYPE}"
 #   --worker-machine-type "${PRIMARY_MACHINE_TYPE}"
    --master-boot-disk-size 600
#    --worker-boot-disk-size 60
#    --secondary-worker-boot-disk-size 60
    --master-local-ssd-interface=NVME
    --num-master-local-ssds=1
    --master-boot-disk-type pd-ssd
#    --master-boot-disk-type hyperdisk-balanced
#    --worker-boot-disk-type pd-ssd
#    --secondary-worker-boot-disk-type pd-ssd
    --region "${REGION}"
    --zone "${ZONE}"
    --subnet "${SUBNET}"
    --no-address
    --service-account "${GSA}"
    --tags "${TAGS}"
    --bucket "${BUCKET}"
    --temp-bucket "${TEMP_BUCKET}"
    --enable-component-gateway
#    --enable-kerberos

    --metadata "${all_metadata}"
    "${image_args[@]}"

#    --no-shielded-secure-boot
    --shielded-secure-boot
#    --initialization-actions "${INIT_ACTIONS_ROOT}/gpu/install_gpu_driver.sh"
#    --initialization-actions "${INIT_ACTIONS_ROOT}/spark-rapids/spark-rapids.sh"
#    --initialization-actions "${INIT_ACTIONS_ROOT}/nfs/nfs.sh"
    --initialization-action-timeout 90m
    --optional-components "DOCKER,JUPYTER"
#    --max-idle="${IDLE_TIMEOUT}"
    --properties "spark:spark.history.fs.logDirectory=gs://${BUCKET}/phs/eventLog"
    --scopes 'https://www.googleapis.com/auth/cloud-platform,sql-admin'
  )

  if [[ "${GCLOUD_QUIET}" != "true" ]]; then
    echo
    echo "Command to be executed:"
    printf "%s\n" "${gcloud_cmd[@]}" | perl -pe 's/ --/  --/g'
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
