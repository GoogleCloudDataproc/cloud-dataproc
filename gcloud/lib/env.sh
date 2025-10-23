#!/bin/bash
#
# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS-IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Set RESOURCE_SUFFIX based on TIMESTAMP env var or generate new
if [[ -n "${TIMESTAMP}" ]]; then
  export RESOURCE_SUFFIX="${TIMESTAMP}"
  echo "Using provided TIMESTAMP for resources: ${RESOURCE_SUFFIX}"
else
  export RESOURCE_SUFFIX="$(date +%s)"
  echo "Generated new TIMESTAMP for resources: ${RESOURCE_SUFFIX}"
fi
export REPRO_TMPDIR="${REPRO_TMPDIR:-/tmp/dataproc-repro/${RESOURCE_SUFFIX}}"
mkdir -p "${REPRO_TMPDIR}"
export SENTINEL_DIR="${SENTINEL_DIR:-${REPRO_TMPDIR}/sentinels}"
mkdir -p "${SENTINEL_DIR}"

source lib/script-utils.sh

export PATH_SEPARATOR=";"
export FOLDER_NUMBER="$(jq -r .FOLDER_NUMBER env.json)"
export DOMAIN="$(jq -r .DOMAIN env.json)"
export USER="$(jq -r .USER env.json)"
export PRIV_DOMAIN="$(jq -r .PRIV_DOMAIN env.json)"
export PRIV_USER="$(jq -r .PRIV_USER env.json)"
export PROJECT_ID="$(jq -r .PROJECT_ID env.json)"
if [[ "${PROJECT_ID}" == "ldap-example-yyyy-nn" ]]; then
  export PROJECT_ID="${USER}-example-$(date +%Y-%U)"
fi
export BILLING_ACCOUNT="$(jq -r .BILLING_ACCOUNT env.json)"
export CLUSTER_NAME="$(jq -r .CLUSTER_NAME env.json)"
export BUCKET="$(jq -r .BUCKET env.json)"
export TEMP_BUCKET="$(jq -r .TEMP_BUCKET env.json)"
export RANGE="$(jq -r .RANGE env.json)"
export IDLE_TIMEOUT="$(jq -r .IDLE_TIMEOUT env.json)"
export ASN_NUMBER="$(jq -r .ASN_NUMBER env.json)"
export IMAGE_VERSION="$(jq -r .IMAGE_VERSION env.json)"
export REGION="$(jq -r .REGION env.json)"
export DEBUG="${DEBUG:-0}"

export ZONE="${REGION}-b"
#export ZONE="${REGION}-b"
#export IMAGE_VERSION="2.0"
#export IMAGE_VERSION="2.0.67-debian10" # final proprietary gpu support - April 26, 2024 - 5.10.0-0.deb10.16-amd64
#export IMAGE_VERSION="2.0.68-debian10" #                               - June  28, 2024 - 5.10.0-0.deb10.16-cloud-amd64
#export IMAGE_VERSION="2.0-ubuntu18"
#export IMAGE_VERSION="2.0-rocky8"
#export IMAGE_VERSION="2.0-debian10"
#export IMAGE_VERSION="2.1"
#export IMAGE_VERSION="2.1.46-debian11" # final proprietary gpu support - April 26, 2024
#export IMAGE_VERSION="2.1-ubuntu20"
#export IMAGE_VERSION="2.1-rocky8"
#export IMAGE_VERSION="2.1-debian11"
#export IMAGE_VERSION="2.1.66-debian11"
#export IMAGE_VERSION="2.2"
#export IMAGE_VERSION="2.2.3-debian12" # final proprietary gpu support - April 26, 2024
#export IMAGE_VERSION="2.2.35-debian12"
#export IMAGE_VERSION="2.2-ubuntu22"
#export IMAGE_VERSION="2.2-rocky9"
#export IMAGE_VERSION="2.2-debian12"
export DATAPROC_IMAGE_VERSION="${IMAGE_VERSION}"
#export INIT_ACTIONS_ROOT="gs://goog-dataproc-initialization-actions-${REGION}"
export AUTOSCALING_POLICY_NAME=aspolicy-${CLUSTER_NAME}
export SA_NAME=sa-${CLUSTER_NAME}

if [[ "${PROJECT_ID}" == *":"* ]]; then
  # Domain-scoped project
  DOMAIN=$(echo "${PROJECT_ID}" | cut -d':' -f1)
  PROJECT_NAME=$(echo "${PROJECT_ID}" | cut -d':' -f2)
  export GSA="${SA_NAME}@${PROJECT_NAME}.${DOMAIN}.iam.gserviceaccount.com"
else
  # Regular project
  export GSA="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
fi

export INIT_ACTIONS_ROOT="gs://${BUCKET}/dataproc-initialization-actions"
export YARN_DOCKER_IMAGE="gcr.io/${PROJECT_ID}/${USER}/cudatest-ubuntu18:latest"
export SPARK_PROPERTIES="spark:spark.yarn.unmanagedAM.enabled=false,spark:spark.task.resource.gpu.amount=1,spark:spark.executor.cores=1,spark:spark.task.cpus=1,spark:spark.executor.memory=4G"
export DOCKER_PROPERTIES="dataproc:docker.yarn.enable=true"
export PROPERTIES="${SPARK_PROPERTIES},${DOCKER_PROPERTIES}"
export CONNECTIVITY_TEST="ct-${CLUSTER_NAME}"

export ALLOCATION_NAME="allocation-${CLUSTER_NAME}-${REGION}"
export NETWORK="net-${CLUSTER_NAME}"
export NETWORK_URI_PARTIAL="projects/${PROJECT_ID}/global/networks/${NETWORK}"
export NETWORK_URI="https://www.googleapis.com/compute/v1/${NETWORK_URI_PARTIAL}"
export SUBNET="subnet-${CLUSTER_NAME}"
export SUBNET_URI_PARTIAL="projects/${PROJECT_ID}/regions/${REGION}/subnetworks/${SUBNET}"
export SUBNET_URI="https://www.googleapis.com/compute/v1/${SUBNET_URI_PARTIAL}"

export FIREWALL="fw-${CLUSTER_NAME}"
export TAGS="tag-${CLUSTER_NAME}"
export ROUTER_NAME="router-${CLUSTER_NAME}"
export PRINCIPAL="${USER}@${DOMAIN}"

# Artifact Registry
export ARTIFACT_REPOSITORY="${PROJECT_ID}-dataproc-repro"

# BigTable
export BIGTABLE_INSTANCE="$(jq -r .BIGTABLE_INSTANCE env.json)"
if [[ "${BIGTABLE_INSTANCE}" == "null" ]]; then
  BIGTABLE_INSTANCE="${USER}-bigtable0"
fi
export BIGTABLE_DISPLAY_NAME="$(jq -r .BIGTABLE_DISPLAY_NAME env.json)"
if [[ "${BIGTABLE_DISPLAY_NAME}" == "null" ]]; then
  BIGTABLE_DISPLAY_NAME="bigtable-${CLUSTER_NAME}"
fi
export BIGTABLE_CLUSTER_CONFIG="$(jq -r .BIGTABLE_CLUSTER_CONFIG env.json)"
if [[ "${BIGTABLE_CLUSTER_CONFIG}" == "null" ]]; then
  BIGTABLE_CLUSTER_CONFIG="id=${BIGTABLE_DISPLAY_NAME},zone=${ZONE},nodes=3"
fi

# PostGres
export PGSQL_INSTANCE="pgsql-${CLUSTER_NAME}"
export PGSQL_DATABASE_VERSION="POSTGRES_9_6"
export PGSQL_ROOT_PASSWORD="nunyabiz"

# MySQL
export MYSQL_INSTANCE="mysql-${CLUSTER_NAME}"
export MYSQL_DATABASE_VERSION="MYSQL_8_0"

export MYSQL_SECRET_NAME="mysql-secret-${CLUSTER_NAME}"

# MSSQL
export MSSQL_INSTANCE="mssql-${CLUSTER_NAME}"

# Oracle
export ORACLE_VM_NAME="oracle-vm-${CLUSTER_NAME}"
export MSSQL_DATABASE_VERSION="SQLSERVER_2019_STANDARD"
# Legacy MSSQL
export MSSQL_IMAGE_FAMILY="sql-ent-2014-win-2012-r2"
export MSSQL_IMAGE_PROJECT="windows-sql-cloud"
export MSSQL_MACHINE_TYPE="n1-standard-8"

# PHS
export PHS_BUCKET="${BUCKET}/*/spark-job-history"
export MR_HISTORY_BUCKET="${BUCKET}/*/mapreduce-job-history/done"

#export MACHINE_TYPE="n1-highmem-8"
#export MACHINE_TYPE="n1-standard-16"
export MACHINE_TYPE="n1-standard-32"
#export MACHINE_TYPE="n1-standard-96"
#export MACHINE_TYPE="e2-standard-2"
# g2- are for l4 GPUs
#export MACHINE_TYPE="g2-standard-4"
#export MACHINE_TYPE="g2-standard-16"
#export MACHINE_TYPE="g2-standard-32"
# a2- are for a100 GPUs
#export MACHINE_TYPE="a2-highgpu-1g"
#export MACHINE_TYPE="a2-highgpu-2g"
# a3- are for h100 GPUs
#export MACHINE_TYPE="a3-highgpu-8g"
#export MACHINE_TYPE="a3-highgpu-2g"
#export MACHINE_TYPE="a3-highgpu-4g"
#export MACHINE_TYPE="n2d-standard-8"
export MASTER_MACHINE_TYPE="${MACHINE_TYPE}"
#export MASTER_MACHINE_TYPE="n1-standard-96"
#export MASTER_MACHINE_TYPE="n1-standard-8"
#export MASTER_MACHINE_TYPE="a2-highgpu-8g"
#export MASTER_MACHINE_TYPE="a3-highgpu-8g"
export PRIMARY_MACHINE_TYPE="${MACHINE_TYPE}"
#export PRIMARY_MACHINE_TYPE="n1-standard-8"
#export PRIMARY_MACHINE_TYPE="g2-standard-4"
#export PRIMARY_MACHINE_TYPE="e2-standard-4"
#export PRIMARY_MACHINE_TYPE="n2d-highmem-32"
export SECONDARY_MACHINE_TYPE="${PRIMARY_MACHINE_TYPE}"

#export CUDNN_VERSION="8.0.5.39"
#export NCCL_VERSION="2.8.4"
#export DRIVER_VERSION="455.45.01"
#export ACCELERATOR_TYPE="nvidia-tesla-p100"
#export ACCELERATOR_TYPE="nvidia-tesla-a100"
#export ACCELERATOR_TYPE="nvidia-tesla-a100,count=2"
export ACCELERATOR_TYPE="nvidia-tesla-t4"
#export ACCELERATOR_TYPE="nvidia-l4"
#export ACCELERATOR_TYPE="nvidia-tesla-p4,count=2"
#export ACCELERATOR_TYPE="nvidia-tesla-p100,count=2"
#export ACCELERATOR_TYPE="nvidia-tesla-v100,count=4"
#export ACCELERATOR_TYPE="nvidia-h100-80gb,count=4"
#export ACCELERATOR_TYPE="nvidia-h100-80gb,count=2"
#export MASTER_ACCELERATOR_TYPE="nvidia-tesla-t4,count=4"
#export MASTER_ACCELERATOR_TYPE="nvidia-tesla-t4"
#export MASTER_ACCELERATOR_TYPE="nvidia-tesla-a100,count=2"
#export MASTER_ACCELERATOR_TYPE="nvidia-tesla-a100,count=8"
#export MASTER_ACCELERATOR_TYPE="nvidia-h100-80gb,count=8"
export MASTER_ACCELERATOR_TYPE="${ACCELERATOR_TYPE}"
export PRIMARY_ACCELERATOR_TYPE="${ACCELERATOR_TYPE}"
export SECONDARY_ACCELERATOR_TYPE="${ACCELERATOR_TYPE}"
#export CUDA_VERSION=10.2.89
#export CUDA_VERSION=11.0
#export DRIVER_VERSION="440.100"
#export CUDA_VERSION=11.1
#export DRIVER_VERSION="455.45.01"
#export CUDA_VERSION=11.2
#export DRIVER_VERSION="460.91.03"
#export CUDA_VERSION=11.3
#export DRIVER_VERSION="465.31"
#export CUDA_VERSION=11.5
#export CUDA_VERSION="11.1"
#export DRIVER_VERSION="455.45.01"
#export DRIVER_VERSION="470.256.02"
#export CUDA_VERSION=11.2
#export CUDA_VERSION=11.7
#export CUDA_VERSION=11.8
#export CUDA_VERSION=12.0
#export CUDA_VERSION=12.1.1
#export CUDA_VERSION=12.2
#export CUDA_VERSION=12.1.1
#export CUDA_VERSION=12.4
# export CUDA_VERSION=12.4.0
#export CUDA_VERSION="12.4.1"
#export DRIVER_VERSION="550.135"
#export CUDA_VERSION="12.6"
#export CUDA_VERSION="12.6.2"
#export CUDA_VERSION="12.6.3"
#export DRIVER_VERSION="550.142"
#export DRIVER_VERSION="460.73.01"
#export DRIVER_VERSION="550.54.14"
#export DRIVER_VERSION="560.35.03"
#export DRIVER_VERSION="550.135"
#export NCCL_VERSION="2.8.3"
#export CUDNN_VERSION="8.0.5.39"
#export NCCL_VERSION="2.8.4"
#export ACCELERATOR_TYPE="nvidia-tesla-p100"

# DPGKE
export DPGKE_NAMESPACE=k8sns-${CLUSTER_NAME}
export GKE_CLUSTER_NAME="gke-${CLUSTER_NAME}"
export DPGKE_CLUSTER_NAME="dpgke-${CLUSTER_NAME}"
export GKE_CLUSTER="projects/${PROJECT_ID}/locations/${ZONE}/clusters/${GKE_CLUSTER_NAME}"
export DP_POOLNAME_DEFAULT=default-pool-${CLUSTER_NAME}
export DP_POOLNAME_WORKER=worker-pool-${CLUSTER_NAME}

export DP_CTRL_POOLNAME="ctrl-${CLUSTER_NAME}"
export DP_DRIVER_POOLNAME="driver-${CLUSTER_NAME}"
export DP_EXEC_POOLNAME="exec-${CLUSTER_NAME}"

# Kerberos
export KMS_KEYRING="keyring-${CLUSTER_NAME}"
export KDC_HOSTNAME=kdc
export KDC_REALM=EXAMPLE.COM
export KDC_DOMAIN=$(echo "${KDC_REALM}" | tr '[:upper:]' '[:lower:]')
export KDC_NAME="kdc-${CLUSTER_NAME}"
export KDC_FQDN="${KDC_HOSTNAME}.${KDC_DOMAIN}"
export KDC_ROOT_PASSWD_KEY="kdc-root-${CLUSTER_NAME}"
export KDC_MACHINE_TYPE=n1-standard-1
export KDC_IMAGE_PROJECT=rocky-linux-cloud
export KDC_IMAGE_FAMILY=rocky-linux-9
export KDC_BOOT_DISK_SIZE=50

# Hive
export HIVE_INSTANCE_NAME="${MYSQL_INSTANCE}"
export HIVE_CLUSTER_NAME="hive-${CLUSTER_NAME}"
export HIVE_DATA_BUCKET="${BUCKET}"
export WAREHOUSE_BUCKET="gs://${HIVE_DATA_BUCKET}"
export HIVE_METASTORE_WAREHOUSE_DIR="${WAREHOUSE_BUCKET}/datasets"

function configure_environment() {
  dataproc_repro_configure_environment=1

  # echo -n "setting gcloud config..."
  # CURRENT_ACCOUNT="$(gcloud config get account)"
  # if [[ "${CURRENT_ACCOUNT}" != "${PRINCIPAL}" ]]; then
  #   echo "setting gcloud account"
  #   gcloud config set account "${PRINCIPAL}"

  # fi
  # CURRENT_COMPUTE_REGION="$(gcloud config get compute/region)"
  # if [[ "${CURRENT_COMPUTE_REGION}" != "${REGION}" ]]; then
  #   echo "setting compute region"
  #   gcloud config set compute/region "${REGION}"
  # fi
  # CURRENT_DATAPROC_REGION="$(gcloud config get dataproc/region)"
  # if [[ "${CURRENT_DATAPROC_REGION}" != "${REGION}" ]]; then
  #   echo "setting dataproc region"
  #   gcloud config set dataproc/region "${REGION}"
  # fi
  # CURRENT_COMPUTE_ZONE="$(gcloud config get compute/zone)"
  # if [[ "${CURRENT_COMPUTE_ZONE}" != "${ZONE}" ]]; then
  #   echo "setting compute zone"
  #   gcloud config set compute/zone "${ZONE}"
  # fi
  # CURRENT_PROJECT_ID="$(gcloud config get project)"
  # if [[ "${CURRENT_PROJECT_ID}" != "${PROJECT_ID}" ]]; then
  #   echo "setting gcloud project"
  #   gcloud config set project ${PROJECT_ID}
  # fi

  # echo "setting gcloud parameters"
  # gcloud config set account ${PRINCIPAL}

  # #gcloud config set compute/region ${REGION}
  # #gcloud config set dataproc/region ${REGION}
  # #gcloud config set compute/zone ${ZONE}
  # #gcloud config set project ${PROJECT_ID}
  # gcloud config set project ${PROJECT_ID}


  #
  # MOK config for secure boot
  #
  eval "$(bash lib/secure-boot/create-key-pair.sh)"
  #modulus_md5sum=cd2bd1bdd9f9e4c43c12aecf6c338d6f
  #private_secret_name=efi-db-priv-key-042
  #public_secret_name=efi-db-pub-key-042
  #secret_project=${PROJECT_ID}
  #secret_version=1

  # The above are used by gpu/instal_gpu_driver.sh to suppy driver
  # signing material to DKMS These configuration options can be
  # generated for the reader if the following lines are uncommented.

  #enable_secret_manager
  #eval $(bash ../custom-images/examples/secure-boot/create-key-pair.sh)

  # To boot a secure-boot capable cluster from a pre-init image, the
  # reader will have already performed the steps from
  # ../custom-images/examples/secure-boot/README.md including creation of creating
  # an env.json in the repo checkout directory.

  # The reader will then need to pass the
  # `--image="projects/${PROJECT_ID}/global/images/"${PURPOSE}-${dataproc_version/\./-}-${timestamp}"`
  # argument instead of `--image-version "${IMAGE_VERSION}"` when
  # performing the gcloud dataproc clusters create command.  Modify the
  # call to gcloud in lib/shared-functions.sh's create_dpgce_cluster
  # function.

}

[[ -v dataproc_repro_configure_environment ]] || configure_environment
