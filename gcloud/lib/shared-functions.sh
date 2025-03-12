#!/bin/bash
#
# Copyright 2021 Google LLC and contributors
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

function create_dpgce_cluster() {
  [[ exists_dpgce_cluster == 0 ]] && echo "dpgce cluster already exists" && return 0

  set -x

  date
  time gcloud dataproc clusters create ${CLUSTER_NAME} \
    --single-node \
    --master-accelerator "type=${MASTER_ACCELERATOR_TYPE}" \
    --worker-accelerator "type=${PRIMARY_ACCELERATOR_TYPE}" \
    --secondary-worker-accelerator "type=${SECONDARY_ACCELERATOR_TYPE}" \
    --master-machine-type "${MASTER_MACHINE_TYPE}" \
    --worker-machine-type "${PRIMARY_MACHINE_TYPE}" \
    --master-boot-disk-size           50 \
    --worker-boot-disk-size           50 \
    --secondary-worker-boot-disk-size 50 \
    --master-boot-disk-type           pd-ssd \
    --worker-boot-disk-type           pd-ssd \
    --secondary-worker-boot-disk-type pd-ssd \
    --format=json \
    --region "${REGION}" \
    --zone "${ZONE}" \
    --subnet "${SUBNET}" \
    --no-address \
    --service-account="${GSA}" \
    --tags="${TAGS}" \
    --bucket "${BUCKET}" \
    --enable-component-gateway \
    --metadata "public_secret_name=${public_secret_name}" \
    --metadata "private_secret_name=${private_secret_name}" \
    --metadata "secret_project=${secret_project}" \
    --metadata "secret_version=${secret_version}" \
    --metadata "modulus_md5sum=${modulus_md5sum}" \
    --metadata cuda-version="${CUDA_VERSION}" \
    --metadata "install-gpu-agent=true" \
    --metadata "gpu-driver-provider=NVIDIA" \
    --metadata "gpu-conda-env=dpgce" \
    --metadata "rapids-mirror-disk=${RAPIDS_MIRROR_DISK_NAME}" \
    --metadata "rapids-mirror-host=${RAPIDS_REGIONAL_MIRROR_ADDR[${REGION}]}"   \
    --metadata "init-actions-repo=${INIT_ACTIONS_ROOT}" \
    --metadata "dask-cloud-logging=true" \
    --metadata dask-runtime="standalone" \
    --metadata rapids-runtime="SPARK" \
    --metadata bigtable-instance=${BIGTABLE_INSTANCE} \
    --metadata include-gpus=1 \
    --initialization-actions "${INIT_ACTIONS_ROOT}/gpu/install_gpu_driver.sh" \
    --image-version "${IMAGE_VERSION}" \
    --no-shielded-secure-boot \
    --initialization-action-timeout=90m \
    --optional-components DOCKER,JUPYTER \
    --max-idle="${IDLE_TIMEOUT}" \
    --properties spark:spark.history.fs.logDirectory=gs://${BUCKET}/phs/eventLog \
    --scopes 'https://www.googleapis.com/auth/cloud-platform,sql-admin'
  date
  set +x
}

#    --metadata include-pytorch=1 \
#    --properties "hive:hive.metastore.warehouse.dir=gs://${HIVE_DATA_BUCKET}/hive-warehouse" \
#    --metadata "hive-metastore-instance=${PROJECT_ID}:${REGION}:${HIVE_INSTANCE_NAME}" \
#    --metadata "db-hive-password-uri=gs://${BUCKET}/dataproc-initialization-actions/mysql_hive_password.encrypted" \
#    --metadata "kms-key-uri=projects/${PROJECT_ID}/locations/global/keyRings/keyring-cluster-1668020639/cryptoKeys/kdc-root-cluster-1668020639" \
#
#    --properties "hive:hive.metastore.warehouse.dir=gs://${HIVE_DATA_BUCKET}/hive-warehouse" \
#  local PIP_PACKAGES='tokenizers==0.10.1,datasets==1.5.0'
#  local CONDA_PACKAGES='pytorch==1.0.1,visions==0.7.1'
#  local PIP_PACKAGES='pymysql==1.1.0,pandas-gbq==0.26.1,google-cloud-secret-manager==2.17.0'
#  local CONDA_PACKAGES="${PIP_PACKAGES}"
#    --properties=^:^dataproc:conda.packages="${CONDA_PACKAGES}":dataproc:pip.packages="${PIP_PACKAGES}" \
#    --metadata "hive-metastore-instance=${PROJECT_ID}:${REGION}:${HIVE_INSTANCE_NAME}" \
#    --metadata "db-hive-password-uri=gs://${BUCKET}/dataproc-initialization-actions/mysql_hive_password.encrypted" \
#    --metadata "kms-key-uri=projects/${PROJECT_ID}/locations/global/keyRings/keyring-cluster-1668020639/cryptoKeys/kdc-root-cluster-1668020639" \
#    --initialization-actions "${INIT_ACTIONS_ROOT}/cloud-sql-proxy/cloud-sql-proxy.sh,${INIT_ACTIONS_ROOT}/ccaas_init.sh" \
#    --initialization-actions "${INIT_ACTIONS_ROOT}/gpu/install_gpu_driver.sh" \
#    --num-masters=1 \
#    --num-workers=2 \
#    --master-machine-type "${MASTER_MACHINE_TYPE}" \
#    --worker-machine-type "${PRIMARY_MACHINE_TYPE}" \
#    --metadata cuda-url="https://developer.download.nvidia.com/compute/cuda/12.4.1/local_installers/cuda_12.4.1_550.54.15_linux.run" \
#    --metadata gpu-driver-url="https://us.download.nvidia.com/XFree86/Linux-x86_64/550.135/NVIDIA-Linux-x86_64-550.135.run" \
#    --metadata gpu-driver-version="${DRIVER_VERSION}" \
#    --initialization-actions ${INIT_ACTIONS_ROOT}/gpu/install_gpu_driver.sh,${INIT_ACTIONS_ROOT}/rapids/rapids.sh \
#    --initialization-actions ${INIT_ACTIONS_ROOT}/rapids/rapids.sh \
#    --metadata rapids-runtime="SPARK" \
#    --worker-accelerator "type=${PRIMARY_ACCELERATOR_TYPE}" \
#    --master-accelerator "type=${MASTER_ACCELERATOR_TYPE}" \
#    --single-node \
#    --num-masters=1 \
#    --num-workers=2 \
#    --metadata cuda-version="${CUDA_VERSION}" \
#    --image "projects/${PROJECT_ID}/global/images/cuda-pre-init-2-0-ubuntu18-2024-12-24-20-42" \
#    --metadata cuda-url="https://developer.download.nvidia.com/compute/cuda/12.4.1/local_installers/cuda_12.4.1_550.54.15_linux.run" \
#    --metadata cuda-url="https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda_11.8.0_520.61.05_linux.run" \
#    --metadata cuda-url="https://developer.download.nvidia.com/compute/cuda/12.4.0/local_installers/cuda_12.4.0_550.54.14_linux.run" \
#    --image "projects/${PROJECT_ID}/global/images/cuda-pre-init-2-2-rocky9-2024-12-01-04-21" \
#    --initialization-actions "${INIT_ACTIONS_ROOT}/gpu/install_gpu_driver.sh" \
#    --image "projects/${PROJECT_ID}/global/images/cuda-pre-init-2-1-debian11-2024-10-31-07-41" \
#    --initialization-actions "${INIT_ACTIONS_ROOT}/gpu/install_gpu_driver.sh" \
#    --image-version "${IMAGE_VERSION}" \
#    --image "projects/${PROJECT_ID}/global/images/cuda-pre-init-2-2-debian12-2024-10-24-09-12" \
#    --image "projects/${PROJECT_ID}/global/images/rapids-pre-init-2-2-debian12-2024-10-15-02-54" \
#    --image "projects/${PROJECT_ID}/global/images/rapids-pre-init-2-2-debian12-2024-10-15-02-54" \
#    --initialization-actions "${INIT_ACTIONS_ROOT}/dask/dask.sh,${INIT_ACTIONS_ROOT}/rapids/rapids.sh" \
#    --metadata dask-runtime="yarn" \
#    --metadata dask-runtime="standalone" \
#    --image-version "${IMAGE_VERSION}" \
#    --no-shielded-secure-boot \
#    --image "projects/${PROJECT_ID}/global/images/custom-2-2-debian12-2024-10-04" \
#    --initialization-actions "${INIT_ACTIONS_ROOT}/sf-env-setup.sh" \
#    --num-masters=1 \
#    --num-workers=2 \
#    --metadata cuda-version="${CUDA_VERSION}" \
#    --initialization-actions "${INIT_ACTIONS_ROOT}/gpu/install_gpu_driver.sh,${INIT_ACTIONS_ROOT}/dask/dask.sh,${INIT_ACTIONS_ROOT}/rapids/rapids.sh" \
#    --num-masters=1 \
#    --num-workers=2 \
#    --initialization-actions "${INIT_ACTIONS_ROOT}/gpu/install_gpu_driver.sh" \
#    --image "projects/${PROJECT_ID}/global/images/custom-2-2-debian12-2024-07-27" \
#    --image "projects/${PROJECT_ID}/global/images/custom-2-2-ubuntu22-2024-07-27" \
#    --image "projects/${PROJECT_ID}/global/images/custom-2-2-rocky9-2024-07-27" \


#    --metadata dask-runtime="standalone" \
#    --initialization-actions "${INIT_ACTIONS_ROOT}/bigtable/bigtable.sh" \
#    --worker-accelerator "type=${ACCELERATOR_TYPE}" \
#    --initialization-actions "${INIT_ACTIONS_ROOT}/gpu/install_gpu_driver.sh" \
#    --image "projects/${PROJECT_ID}/global/images/nvidia-open-kernel-bookworm-2024-06-26" \
#    --image-version "${IMAGE_VERSION}" \
#    --image "projects/${PROJECT_ID}/global/images/nvidia-open-kernel-bookworm-2024-06-21-a" \
#    --no-shielded-secure-boot \
#    --image-version "${IMAGE_VERSION}" \
#    --initialization-actions "${INIT_ACTIONS_ROOT}/gpu/install_gpu_driver.sh" \

#
# GPU
#
    # --optional-components JUPYTER,ZOOKEEPER \
    # --worker-accelerator type=${ACCELERATOR_TYPE} \
    # --master-accelerator type=${ACCELERATOR_TYPE} \
    # --metadata include-gpus=true \
    # --metadata gpu-driver-provider=NVIDIA \
    # --metadata install-gpu-agent=true \
    # --initialization-action-timeout=15m \
    # --initialization-actions ${INIT_ACTIONS_ROOT}/gpu/install_gpu_driver.sh \
    # --properties='^#^dataproc:conda.packages=ipython-sql==0.3.9,pyhive==0.6.5' \
    # --properties spark:spark.executor.resource.gpu.amount=1,spark:spark.task.resource.gpu.amount=1 \
    # --properties "presto-catalog:bigquery_my_other_project.connector.name"="bigquery" \



#    --image https://www.googleapis.com/compute/v1/projects/cloud-dataproc-ci/global/images/dataproc-2-0-debian10-20240314-212221-rc99 \
#    --initialization-actions "${INIT_ACTIONS_ROOT}/hue/hue.sh" \
#     --metadata startup-script-url="${INIT_ACTIONS_ROOT}/delay-masters-startup.sh" \
#     --scopes 'https://www.googleapis.com/auth/cloud-platform,sql-admin'

#
# DASK rapids
#
    # --metadata rapids-runtime=DASK \
    # --metadata cuda-version="${CUDA_VERSION}" \
    # --metadata rapids-version="22.04" \
    # --initialization-actions ${INIT_ACTIONS_ROOT}/gpu/install_gpu_driver.sh,${INIT_ACTIONS_ROOT}/rapids/rapids.sh \

#     --metadata ="$(perl -n -e '@l=<STDIN>; chomp @l; print join q{,}, @l' <init/dataproc.${CASE_NUMBER}.metadata)" \

#    --max-idle=${IDLE_TIMEOUT} \

# 20240724 vvv  prior ^^^

    # --initialization-actions "${INIT_ACTIONS_ROOT}/gpu/install_gpu_driver.sh" \
    # --metadata rapids-runtime="DASK" \
    # --metadata rapids-version="23.12" \
    # --metadata install-gpu-agent="true" \
    # --metadata cuda-version="${CUDA_VERSION}" \
    # --metadata "public_secret_name=efi-db-pub-key-005" \
    # --metadata "private_secret_name=efi-db-priv-key-005" \
    # --metadata "secret_project=${PROJECT_ID}" \
    # --metadata "secret_version=1" \
    # --metadata "modulus_md5sum=1bd7778c62497c257ea1cd0c766a593e" \




#
# bigtable
#
    # --initialization-actions "${INIT_ACTIONS_ROOT}/bigtable/bigtable.sh" \
    # --metadata bigtable-instance=${BIGTABLE_INSTANCE} \
    # --initialization-action-timeout=15m \

#
# Oozie
#
#    --metadata startup-script-url="${INIT_ACTIONS_ROOT}/delay-masters-startup.sh" \
#    --initialization-actions "${INIT_ACTIONS_ROOT}/oozie/oozie.sh" \
#    --properties "dataproc:dataproc.master.custom.init.actions.mode=RUN_AFTER_SERVICES" \

#
# Livy
#
#    --initialization-actions "${INIT_ACTIONS_ROOT}/livy/livy.sh" \

# complex init actions on 2.1 repro

    # --metadata startup-script-url="${INIT_ACTIONS_ROOT}/delay-masters-startup.sh" \
    # --initialization-actions "${INIT_ACTIONS_ROOT}/oozie/oozie.sh,${INIT_ACTIONS_ROOT}/bigtable/bigtable.sh,${INIT_ACTIONS_ROOT}/sqoop/sqoop.sh" \
    # --initialization-action-timeout=15m \
    # --optional-components ZOOKEEPER \
    # --metadata "hive-metastore-instance=${PROJECT_ID}:${REGION}:${HIVE_INSTANCE_NAME}" \
    # --metadata hive-cluster-name="${HIVE_CLUSTER_NAME}" \
    # --metadata bigtable-instance="${BIGTABLE_INSTANCE}" \
    # --metadata bigtable-project="${PROJECT_ID}" \
    # --properties="^~~^$(perl -n -e '@l=<STDIN>; chomp @l; print join q{~~}, @l' <init/dataproc.${CASE_NUMBER}.properties)" \
    # --scopes 'https://www.googleapis.com/auth/cloud-platform,sql-admin'

#    --enable-component-gateway \
#    --metadata startup-script-url="${INIT_ACTIONS_ROOT}/delay-masters-startup.sh" \
#    --initialization-actions "${INIT_ACTIONS_ROOT}/oozie/oozie.sh,${INIT_ACTIONS_ROOT}/bigtable/bigtable.sh,${INIT_ACTIONS_ROOT}/sqoop/sqoop.sh" \
#    --initialization-action-timeout=15m \
#    --properties "dataproc:dataproc.master.custom.init.actions.mode=RUN_AFTER_SERVICES" \
#    --initialization-action-timeout=15m \
#    --metadata bigtable-instance=${BIGTABLE_INSTANCE} \

#     --metadata startup-script-url="${INIT_ACTIONS_ROOT}/delay-masters-startup.sh" \
#     --properties "dataproc:dataproc.master.custom.init.actions.mode=RUN_AFTER_SERVICES" \

#    --initialization-actions "${INIT_ACTION_PATHS}" \
#    --initialization-actions ${INIT_ACTIONS_ROOT}/oozie/oozie.sh,${INIT_ACTIONS_ROOT}/bigtable/bigtable.sh,${INIT_ACTIONS_ROOT}/sqoop/sqoop.sh \
#    --initialization-actions ${INIT_ACTIONS_ROOT}/oozie/oozie.sh \

# [serial] new initialization action to execute in serial #1086
# https://github.com/GoogleCloudDataproc/initialization-actions/pull/1086
#    --initialization-actions ${INIT_ACTIONS_ROOT}/serial/serial.sh \
#    --metadata "initialization-action-paths=${INIT_ACTION_PATHS}" \
#    --metadata "initialization-action-paths-separator=${PATH_SEPARATOR}" \


    # --worker-boot-disk-type pd-ssd \
    # --worker-boot-disk-size 50 \
    # --worker-machine-type ${MACHINE_TYPE} \
    # --num-masters=3 \
    # --num-workers=3 \


  #    --metadata spark-bigquery-connector-version=0.31.1 \

    # --worker-boot-disk-type pd-ssd \
    # --worker-boot-disk-size 50 \
    # --worker-machine-type ${MACHINE_TYPE} \
    # --num-workers=3 \

#      --single-node \


    # --no-shielded-secure-boot \
    # --worker-accelerator type=${ACCELERATOR_TYPE} \
    # --master-accelerator type=${ACCELERATOR_TYPE} \
    # --metadata include-gpus=true \
    # --metadata gpu-driver-provider=NVIDIA \
    # --initialization-action-timeout=15m \
    # --initialization-actions ${INIT_ACTIONS_ROOT}/gpu/install_gpu_driver.sh \
    # --properties spark:spark.executor.resource.gpu.amount=1,spark:spark.task.resource.gpu.amount=1 \
    # --metadata init-actions-repo=${INIT_ACTIONS_ROOT} \
    # --metadata install-gpu-agent=true \
    # --metadata cuda-version=${CUDA_VERSION} \

#,${INIT_ACTIONS_ROOT}/nvidia_docker.sh \
  #    --max-idle=${IDLE_TIMEOUT} \
#    --initialization-action-timeout=15m \
#    --worker-accelerator type=${ACCELERATOR_TYPE} \
#    --master-accelerator type=${ACCELERATOR_TYPE} \
  #     --metadata gpu-driver-provider=NVIDIA \
    # --initialization-actions ${INIT_ACTIONS_ROOT}/gpu/install_gpu_driver.sh \

#    --image-version 1.4.80-ubuntu18 \


# Increase log verbosity
#   --verbosity=debug \

#
# Kafka
#

#    --optional-components ZOOKEEPER \
#    --metadata "run-on-master=true" \
#    --initialization-actions gs://goog-dataproc-initialization-actions-${REGION}/kafka/kafka.sh \

#
# Hive
#

# tested 20240719
#    --initialization-actions "${INIT_ACTIONS_ROOT}/cloud-sql-proxy/cloud-sql-proxy.sh" \
#    --properties "hive:hive.metastore.warehouse.dir=gs://${HIVE_DATA_BUCKET}/hive-warehouse" \
#    --metadata "hive-metastore-instance=${PROJECT_ID}:${REGION}:${HIVE_INSTANCE_NAME}" \
#    --metadata "db-hive-password-uri=gs://${BUCKET}/dataproc-initialization-actions/mysql_hive_password.encrypted" \
#    --metadata "kms-key-uri=projects/${PROJECT_ID}/locations/global/keyRings/keyring-cluster-1668020639/cryptoKeys/kdc-root-cluster-1668020639" \



#
#    --metadata "hive-metastore-instance=${PROJECT_ID}:${REGION}:${HIVE_INSTANCE_NAME}" \
#    --metadata hive-cluster-name="${HIVE_CLUSTER_NAME}" \
#    --metadata bigtable-instance="${BIGTABLE_INSTANCE}" \
#    --metadata bigtable-project="${PROJECT_ID}" \
#    --properties="^~~^$(perl -n -e '@l=<STDIN>; chomp @l; print join q{~~}, @l' <init/dataproc.${CASE_NUMBER}.properties)" \

#    --initialization-actions gs://goog-dataproc-initialization-actions-${REGION}/cloud-sql-proxy/cloud-sql-proxy.sh \
#    --properties hive:hive.metastore.warehouse.dir=gs://${HIVE_DATA_BUCKET}/hive-warehouse \
#    --metadata "hive-metastore-instance=${PROJECT_ID}:${REGION}:${HIVE_INSTANCE_NAME}" \
#    --scopes 'https://www.googleapis.com/auth/cloud-platform,sql-admin'

#    --single-node \

#    --initialization-actions ${INIT_ACTIONS_ROOT}/cloud-sql-proxy/cloud-sql-proxy.sh \
#    --num-workers=2 \
#    --autoscaling-policy=${AUTOSCALING_POLICY_NAME} \
#    --scopes 'https://www.googleapis.com/auth/cloud-platform'

#
#  Cluster options
#    --optional-components FLINK \
#    --num-worker-local-ssds 4 \
#     --initialization-actions ${INIT_ACTIONS_ROOT}/fail.sh \
#    --optional-components FLINK \

#    --optional-components JUPYTER,ZOOKEEPER \
#    --properties="^~~^$(perl -n -e '@l=<STDIN>; chomp @l; print join q{~~}, @l' <init/${CASE_NUMBER}/dataproc.properties)"
#    --initialization-actions ${INIT_ACTIONS_ROOT}/init-ab0bffe.bash \
#    --initialization-actions ${INIT_ACTIONS_ROOT}/s-agent-dm-filterer.sh \
#
#    --num-masters=3 \
#    --num-workers=2 \
#    --single-node \
#    --master-machine-type n1-standard-4 \
#    --master-boot-disk-type pd-ssd \
#    --master-boot-disk-size 50 \
#    --num-master-local-ssds 4 \
#    --worker-machine-type n1-standard-4 \
#    --worker-boot-disk-type pd-ssd \
#    --worker-boot-disk-size 200 \
#    --num-secondary-workers 2 \
#    --secondary-worker-boot-disk-size 50 \
#    --secondary-worker-boot-disk-type pd-standard \
#    --secondary-worker-type preemptible \
#    --bucket ${BUCKET} \
#    --max-idle=30m \
#    --enable-component-gateway \
#    --optional-components JUPYTER,ZOOKEEPER \
#    --properties="${PROPERTIES}" \
#    --properties="core:fs.defaultFS=gs://${BUCKET}" \
#    --properties="yarn:yarn.log-aggregation-enable=true" \
#    --properties="^~~^$(perl -n -e '@l=<STDIN>; chomp @l; print join q{~~}, @l' <init/dataproc.properties)" \
#    --properties-file=${INIT_ACTIONS_ROOT}/dataproc.properties \

#
#  Test startup scripts and init action scripts
#
#    --metadata startup-script-url="${INIT_ACTIONS_ROOT}/startup-script.pl" \
#    --metadata startup-script-url="${INIT_ACTIONS_ROOT}/startup-script.sh" \
#    --metadata startup-script-url="${INIT_ACTIONS_ROOT}/env-change.sh" \
#    --metadata ^~~^startup-script="$(cat init/startup-script.pl)" \
#    --metadata ^~~^startup-script="$(cat init/startup-script.sh)" \
#    --metadata ^~~^startup-script="$(cat init/startup-script-logsrc.sh)" \
#    --initialization-actions ${INIT_ACTIONS_ROOT}/startup-script.pl \
#    --initialization-actions ${INIT_ACTIONS_ROOT}/startup-script.sh \
#    --initialization-actions ${INIT_ACTIONS_ROOT}/sqoop/sqoop.sh \
#    --initialization-actions ${INIT_ACTIONS_ROOT}/kernel/upgrade-kernel.sh \
#    --metadata startup-script='#!/bin/bash
# echo "hello world xyz"
# ' \
#     --metadata startup-script='#!/bin/bash
# CONNECTOR_JARS=$(find / -iname "*spark-bigquery-connector*.jar")
# for jar in ${CONNECTOR_JARS}; do rm $(realpath ${jar}); done
# rm ${CONNECTOR_JARS}
#  ' \


#
# bigtable
#
#    --metadata bigtable-instance=${BIGTABLE_INSTANCE} \
#    --initialization-actions ${INIT_ACTIONS_ROOT}/bigtable/bigtable.sh \
#
#
#  Oozie
#
#    --initialization-actions ${INIT_ACTIONS_ROOT}/oozie/oozie.sh \

#
#  Conda
#
#    --properties="dataproc:conda.env.config.uri=${INIT_ACTIONS_ROOT}/environment.yaml" \
#    --single-node \
#    --properties="dataproc:dataproc.logging.stackdriver.enable=true" \
#    --properties="dataproc:dataproc.logging.stackdriver.job.driver.enable=true" \
#    --properties="dataproc:dataproc.logging.stackdriver.job.yarn.container.enable=true" \
#    --properties="dataproc:dataproc.monitoring.stackdriver.enable=true" \


#
# NVIDIA
#
#    --metadata include-gpus=true \
#    --worker-accelerator type=${ACCELERATOR_TYPE} \
#    --master-accelerator type=${ACCELERATOR_TYPE} \
#    --metadata gpu-driver-provider=NVIDIA \
#    --metadata init-actions-repo=${INIT_ACTIONS_ROOT} \
#    --metadata install-gpu-agent=true \
#    --metadata cuda-version=${CUDA_VERSION} \


#
# NVidia Docker on yarn
#
#    --metadata yarn-docker-image=${YARN_DOCKER_IMAGE} \
#    --optional-components DOCKER \
#    --initialization-actions ${INIT_ACTIONS_ROOT}/kernel/upgrade-kernel.sh \
#    --initialization-actions ${INIT_ACTIONS_ROOT}/util/upgrade-kernel.sh,${INIT_ACTIONS_ROOT}/gpu/install_gpu_driver.sh,${INIT_ACTIONS_ROOT}/nvidia_docker.sh \

#
# Presto
#
#    --optional-components PRESTO \

#
# HBase
#
#    --optional-components HBASE,ZOOKEEPER \

# Flink
#    --optional-components FLINK \

#
# Rapids
#
#    --metadata rapids-runtime=SPARK \
#    --metadata rapids-runtime=DASK \
#    --initialization-actions ${INIT_ACTIONS_ROOT}/spark-rapids/spark-rapids.sh \

#
# passing properties (to a job only) in a file
#
# --properties-file=${INIT_ACTIONS_ROOT}/dataproc.properties

#    cloud-dataproc-ci.googleapis.com \ # DPMS dependency?
function enable_services () {
  # Enable Dataproc service
  set -x
  gcloud services enable \
    dataproc.googleapis.com \
    compute.googleapis.com \
    secretmanager.googleapis.com \
    --project=${PROJECT_ID}
  set +x
}

REPRO_TMPDIR="$(mktemp -d /tmp/dataproc-repro-XXXXX)"
function cleanup_repro_tmpdir() {
  rm -rf "${REPRO_TMPDIR}"
}

function exit_handler() {
  cleanup_repro_tmpdir
}

trap exit_handler EXIT

function exists_dpgce_cluster() {
  set +x
  test -f cluster-list.json || gcloud dataproc clusters list --format=json | dd of="${REPRO_TMPDIR}/cluster-list.json"
  DPGCE_CLUSTER="$()"
  JQ_CMD=".[] | select(.clusterName | test(\"${CLUSTER_NAME}$\"))"
  OUR_CLUSTER=$(cat ${REPRO_TMPDIR}/cluster-list.json | jq -c "${JQ_CMD}")

  if [[ -z "${OUR_CLUSTER}" ]]; then
    return -1
  else
    echo "cluster exists"
    return 0
  fi
}

function delete_dpgce_cluster() {
  set -x
  if exists_dpgce_cluster == 0; then
    echo "dpgce cluster exists"
  else
    echo "dpgce cluster does not exist.  Not deleting"
    set +x
    return 0
  fi

  gcloud dataproc clusters delete --quiet --region ${REGION} ${CLUSTER_NAME}
  set +x
  echo "cluster deleted"
}

DATE=$(date +%s)
function set_cluster_name() {
  cluster_name="$(jq -r .CLUSTER_NAME env.json)"

  # Only update cluster if it is not set
  if [[ -z "${cluster_name}" || "${cluster_name}" == "null"  ]]; then
    export CLUSTER_NAME="cluster-${DATE}"
  else
    echo "CLUSTER_NAME already set to [${cluster_name}]"
  fi

  # ../env.json is the source of truth.  modify and reload env.sh
  cp ../env.json ../env.json.tmp
  cat ../env.json.tmp | jq ".CLUSTER_NAME |= \"${CLUSTER_NAME}\"" > ../env.json
  rm ../env.json.tmp
  source lib/env.sh
}

function create_project(){
  set -x
  local PROJ_DESCRIPTION=$(gcloud projects describe ${PROJECT_ID} --format json 2>/dev/null)
  if [[ -n ${PROJ_DESCRIPTION} && "$(echo $PROJ_DESCRIPTION | jq -r .lifecycleState)" == "ACTIVE" ]]; then
    echo "project already exists!"
    return
  else
    local LCSTATE="$(echo $PROJ_DESCRIPTION | jq .lifecycleState)"
    if [[ -n ${PROJ_DESCRIPTION} && "$(echo $PROJ_DESCRIPTION | jq -r .lifecycleState)" == "DELETE_REQUESTED" ]]; then
      gcloud projects undelete --quiet ${PROJECT_ID}
    else
      gcloud projects create ${PROJECT_ID} --folder ${FOLDER_NUMBER}
    fi

    if [[ $? -ne 0 ]]; then
      echo "could not create project."
      exit -1
    fi

    local PRJBA=$(gcloud beta billing projects describe ${PROJECT_ID} --format json | jq -r .billingAccountName)

    # link project to billing account
    if [[ -z "${PRJBA}" ]]; then
      set +x
      echo "
The following variable values were read from env.json
PROJECT_ID=${PROJECT_ID}
BILLING_ACCOUNT=${BILLING_ACCOUNT}
PRIV_DOMAIN=${PRIV_DOMAIN}
DOMAIN=${DOMAIN}
USER=${USER}

https://cloud.google.com/billing/docs/how-to/billing-access

Please be prepared to link the project ${PROJECT_ID} to the billing
account ${BILLING_ACCOUNT}.  The principal indicated by
${PRIV_USER}@${PRIV_DOMAIN} must have roles/billing.admin as
documented in above link.

Please encode the principal with rights to modify billing details as
PRIV_USER and PRIV_DOMAIN in your env.json file.

If you have not yet done this, please cancel this operation (^C),
modify your env.json file to include the privileged principal user and
domain, and then re-run this command.

gcloud beta billing projects \
  link ${PROJECT_ID} --billing-account ${BILLING_ACCOUNT}

once you have credentials to run the above command,

Press enter > 
"
      read

      local active_account=$(gcloud auth list 2>/dev/null | awk '/^\*/ {print $2}')
      while [[ $active_account != "${USER}@${PRIV_DOMAIN}" ]]; do
        echo "AUTHENTICATE AS A USER WITH PRIVILEGES TO LINK THESE PROJECTS"
        gcloud auth login ${USER}@${PRIV_DOMAIN}
        local active_account=$(gcloud auth list 2>/dev/null | awk '/^\*/ {print $2}')
      done

      set -x
      execute_with_retries "gcloud beta billing projects link ${PROJECT_ID} --billing-account ${BILLING_ACCOUNT}"
      set +x
      if [[ $? != 0 ]]; then
        echo "failed to link project and billing account"
        exit -1
      fi

      echo "Prepare to log in with your @${DOMAIN} account and then press enter..."
      read

      local active_account=$(gcloud auth list 2>/dev/null | awk '/^\*/ {print $2}')
      while [[ $active_account != "${USER}@${DOMAIN}" ]]; do
        echo "AUTHENTICATE AS YOUR @${DOMAIN} EMAIL ADDRESS"
        gcloud auth login ${USER}@${DOMAIN}
        local active_account=$(gcloud auth list 2>/dev/null | awk '/^\*/ {print $2}')
      done
    fi
  fi
  set +x
  echo "project created!"
}

function delete_project() {
  set -x
  local active_account=$(gcloud auth list 2>/dev/null | awk '/^\*/ {print $2}')
  while [[ $active_account != "${USER}@${PRIV_DOMAIN}" ]]; do
    echo "AUTHENTICATE AS YOUR @${PRIV_DOMAIN} EMAIL ADDRESS"
    gcloud auth login ${USER}@${PRIV_DOMAIN}
    local active_account=$(gcloud auth list 2>/dev/null | awk '/^\*/ {print $2}')
  done
  gcloud beta billing projects unlink ${PROJECT_ID}
  local active_account=$(gcloud auth list 2>/dev/null | awk '/^\*/ {print $2}')
  while [[ $active_account != "${USER}@${DOMAIN}" ]]; do
    echo "AUTHENTICATE AS YOUR @${DOMAIN} EMAIL ADDRESS"
    gcloud auth login ${USER}@${DOMAIN}
    local active_account=$(gcloud auth list 2>/dev/null | awk '/^\*/ {print $2}')
  done
  gcloud projects delete --quiet ${PROJECT_ID}
  set +x
  echo "project deleted!"
}

function configure_gcloud() {
  gcloud config set compute/region ${REGION}
  gcloud config set compute/zone ${ZONE}
  gcloud config set core/project ${PROJECT_ID}
}

function grant_kms_roles(){
  set -x

  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${GSA}" \
    --role=roles/cloudkms.cryptoKeyDecrypter \

  set +x
  echo "dpgke service account roles granted"
}

function grant_mysql_roles(){
  set -x

  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${GSA}" \
    --role=roles/cloudsql.editor \

  set +x
  echo "cloudsql service account editor role granted"
}

function create_mysql_admin_password() {
    dd if=/dev/urandom bs=8 count=4 | xxd -p | \
      gcloud kms encrypt \
      --location=global \
      --keyring=projects/${PROJECT_ID}/locations/global/keyRings/${KMS_KEYRING} \
      --key=projects/${PROJECT_ID}/locations/global/keyRings/${KMS_KEYRING}/cryptoKeys/${KDC_ROOT_PASSWD_KEY} \
      --plaintext-file=- \
      --ciphertext-file=init/mysql_admin_password.encrypted
}


function grant_bigtables_roles(){
  set -x

  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${GSA}" \
    --role=roles/bigtable.user \

  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${GSA}" \
    --role=roles/bigtable.admin \

  set +x
  echo "dpgke service account roles granted"
}


function create_kms_keyring() {
  set -x
  if (gcloud kms keyrings list --location global | grep ${KMS_KEYRING}); then
    echo "keyring already exists"
  else
    gcloud kms keyrings create ${KMS_KEYRING} --location=global
    echo "kms keyring created"
  fi

  set +x
}

function create_kerberos_kdc_key() {
  set -x
  if (gcloud kms keys list --location global --keyring=${KMS_KEYRING} | grep ${KDC_ROOT_PASSWD_KEY}); then
    echo "kerberos kdc key exists"
  else
    gcloud kms keys create ${KDC_ROOT_PASSWD_KEY} \
      --location=global \
      --keyring=${KMS_KEYRING} \
      --purpose=encryption
    echo "kerberos kdc key created"
  fi
  set +x
}

function create_kerberos_kdc_password() {
  set -x
  if [[ -f init/${KDC_ROOT_PASSWD_KEY}.encrypted ]]; then
    echo "password exists"
  else
    dd if=/dev/urandom bs=8 count=4 | xxd -p | \
      gcloud kms encrypt \
      --location=global \
      --keyring=${KMS_KEYRING} \
      --key=${KDC_ROOT_PASSWD_KEY} \
      --plaintext-file=- \
      --ciphertext-file=init/${KDC_ROOT_PASSWD_KEY}.encrypted
  fi
  set +x
}

function create_kerberos_sa_password() {
    dd if=/dev/urandom bs=8 count=4 | xxd -p | \
      gcloud kms encrypt \
      --location=global \
      --keyring=${KMS_KEYRING} \
      --key=${KDC_ROOT_PASSWD_KEY} \
      --plaintext-file=- \
      --ciphertext-file=init/${KDC_SA_PASSWD_KEY}.encrypted
}

function create_kdc_server() {
  # Authors: oklev@softserveinc.com
  set -x

  local METADATA="kdc-root-passwd=${INIT_ACTIONS_ROOT}/${KDC_ROOT_PASSWD_KEY}.encrypted"
  METADATA="${METADATA},kms-keyring=${KMS_KEYRING}"
  METADATA="${METADATA},kdc-root-passwd-key=${KDC_ROOT_PASSWD_KEY}"
  METADATA="${METADATA},startup-script-url=${INIT_ACTIONS_ROOT}/kdc-server.sh"
  METADATA="service-account-user=${GSA}"
  # Spin up a KDC server
  gcloud compute instances create ${KDC_NAME} \
    --zone ${ZONE} \
    --subnet ${SUBNET} \
    --service-account=${GSA} \
    --boot-disk-type pd-ssd \
    --image-family=${KDC_IMAGE_FAMILY} \
    --image-project=${KDC_IMAGE_PROJECT} \
    --machine-type=${MACHINE_TYPE} \
    --scopes='cloud-platform' \
    --hostname=${KDC_FQDN} \
    --metadata ${METADATA}
  set +x
}

function delete_kdc_server() {
  set -x
  gcloud compute instances delete ${KDC_NAME} \
    --quiet
  set +x
  echo "kdc deleted"
}

function create_kerberos_cluster() {
  # https://cloud.google.com/dataproc/docs/concepts/components/ranger#installation_steps
  set -x
  gcloud dataproc clusters create ${CLUSTER_NAME} \
    --region ${REGION} \
    --zone ${ZONE} \
    --subnet ${SUBNET} \
    --no-address \
    --service-account=${GSA} \
    --master-machine-type n1-standard-4 \
    --master-boot-disk-type pd-ssd \
    --master-boot-disk-size 50 \
    --image-version ${IMAGE_VERSION} \
    --bucket ${BUCKET} \
    --initialization-action-timeout=10m \
    --max-idle=${IDLE_TIMEOUT} \
    --enable-component-gateway \
    --scopes='cloud-platform' \
    --enable-kerberos \
    --kerberos-root-principal-password-uri="${INIT_ACTIONS_ROOT}/${KDC_ROOT_PASSWD_KEY}.encrypted" \
    --kerberos-kms-key="${KDC_ROOT_PASSWD_KEY}" \
    --kerberos-kms-key-keyring=${KMS_KEYRING} \
    --kerberos-kms-key-location=global \
    --kerberos-kms-key-project=${PROJECT_ID}

  set +x
  echo "kerberos cluster created"
}

function delete_kerberos_cluster() {
  set -x
  gcloud dataproc clusters delete --quiet --region ${REGION} ${CLUSTER_NAME}
  set +x
  echo "kerberos cluster deleted"
}

function create_phs_cluster() {
# does not include "dataproc:job.history.to-gcs.enabled=true,", as this is a dataproc2 image
  set -x
  gcloud dataproc clusters create ${CLUSTER_NAME}-phs \
    --region=${REGION} \
    --single-node \
    --image-version=${IMAGE_VERSION} \
    --subnet=${SUBNET} \
    --tags=${TAGS} \
    --properties="spark:spark.history.fs.logDirectory=gs://${PHS_BUCKET},spark:spark.eventLog.dir=gs://${PHS_BUCKET}" \
    --properties="mapred:mapreduce.jobhistory.read-only.dir-pattern=gs://${MR_HISTORY_BUCKET}" \
    --enable-component-gateway
  set +x

  echo "==================="
  echo "PHS Cluster created"
  echo "==================="
}

function delete_phs_cluster() {
  set -x
  gcloud dataproc clusters delete --quiet --region ${REGION} ${CLUSTER_NAME}-phs
  set +x
  echo "phs cluster deleted"
}

function create_service_account() {
  set -x
  if gcloud iam service-accounts describe "${GSA}" > /dev/null ; then
    echo "service account ${SA_NAME} already exists"
    return 0 ; fi

  gcloud iam service-accounts create "${SA_NAME}" \
    --description="Service account for use with cluster ${CLUSTER_NAME}" \
    --display-name="${SA_NAME}"

  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${GSA}" \
    --role=roles/dataproc.worker

  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${GSA}" \
    --role=roles/storage.objectCreator

  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${GSA}" \
    --role=roles/storage.objectViewer

  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${GSA}" \
    --role=roles/secretmanager.secretAccessor

  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${GSA}" \
    --role=roles/compute.viewer

  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${GSA}" \
    --role=roles/compute.instanceAdmin.v1

   gcloud iam service-accounts add-iam-policy-binding "${GSA}" \
    --member="serviceAccount:${GSA}" \
    --role=roles/iam.serviceAccountUser

  set +x
  echo "service account created"
}

function delete_service_account() {
  set -x

  for svc in spark-executor spark-driver agent ; do
    gcloud iam service-accounts remove-iam-policy-binding \
      --role=roles/iam.workloadIdentityUser \
      --member="serviceAccount:${PROJECT_ID}.svc.id.goog[${DPGKE_NAMESPACE}/${svc}]" \
      "${GSA}"
  done

  gcloud projects remove-iam-policy-binding \
    --role=roles/dataproc.worker \
    --member="serviceAccount:${GSA}" \
    "${PROJECT_ID}"

  gcloud projects remove-iam-policy-binding \
    --role=roles/storage.objectCreator \
    --member="serviceAccount:${GSA}" \
    "${PROJECT_ID}"

  gcloud projects remove-iam-policy-binding \
    --role=roles/storage.objectViewer \
    --member="serviceAccount:${GSA}" \
    "${PROJECT_ID}"

  gcloud iam service-accounts delete --quiet "${GSA}"

  set +x
  echo "service account deleted"
}

function create_artifacts_repository(){
  set -x
  gcloud artifacts repositories create "${ARTIFACT_REPOSITORY}" \
    --repository-format=docker \
    --location="${REGION}"
  set +x
}

function push_container_image() {
  gcloud auth print-access-token \
    --impersonate-service-account "${GSA}" \
      | docker login \
	  -u oauth2accesstoken \
          --password-stdin "https://${REGION}-docker.pgk.dev"
}

function grant_gke_roles(){
  set -x
  for svc in agent spark-driver spark-executor ; do
    gcloud iam service-accounts add-iam-policy-binding \
      --role=roles/iam.workloadIdentityUser \
      --member="serviceAccount:${PROJECT_ID}.svc.id.goog[${DPGKE_NAMESPACE}/${svc}]" \
      "${GSA}" > /dev/null
  done
  echo gcloud artifacts repositories add-iam-policy-binding "${ARTIFACT_REPOSITORY}" \
      --location="${REGION}" \
      --member="serviceAccount:${GSA}" \
      --role=roles/artifactregistry.writer > /dev/null
  set +x
  echo "dpgke service account roles granted"
}

function create_gke_cluster() {
  set -x

  if gcloud container clusters describe "${GKE_CLUSTER_NAME}" > /dev/null ; then
    echo "GKE cluster ${GKE_CLUSTER_NAME} already exists"
  else
    gcloud container clusters create "${GKE_CLUSTER_NAME}" \
      --service-account="${GSA}" \
      --workload-pool="${PROJECT_ID}.svc.id.goog" \
      --tags ${TAGS} \
      --subnetwork ${SUBNET} \
      --network ${NETWORK}
  fi

  # # Create node pool for control
  # echo gcloud container node-pools describe "${DP_CTRL_POOLNAME}" \
  #   --zone "${ZONE}" --cluster "${GKE_CLUSTER_NAME}" > /dev/null \
  #   && echo "nodepool ${DP_CTRL_POOLNAME} for cluster ${GKE_CLUSTER_NAME} already exists" \
  # || gcloud container node-pools create "${DP_CTRL_POOLNAME}" \
  #   --machine-type="e2-standard-4" \
  #   --zone "${ZONE}" \
  #   --cluster "${GKE_CLUSTER_NAME}"

  # # Create node pool for drivers
  # echo gcloud container node-pools describe "${DP_DRIVER_POOLNAME}" \
  #   --zone "${ZONE}" --cluster "${GKE_CLUSTER_NAME}" > /dev/null \
  #   && echo "nodepool ${DP_DRIVER_POOLNAME} for cluster ${GKE_CLUSTER_NAME} already exists" \
  # || gcloud container node-pools create "${DP_DRIVER_POOLNAME}" \
  #   --machine-type="n2-standard-4" \
  #   --zone "${ZONE}" \
  #   --cluster "${GKE_CLUSTER_NAME}"

  # # Create node pool for executors
  # echo gcloud container node-pools describe "${DP_EXEC_POOLNAME}" \
  #   --zone "${ZONE}" --cluster "${GKE_CLUSTER_NAME}" > /dev/null \
  #   && echo "nodepool ${DP_EXEC_POOLNAME} for cluster ${GKE_CLUSTER_NAME} already exists" \
  # || gcloud container node-pools create "${DP_EXEC_POOLNAME}" \
  #   --machine-type="n2-standard-8" \
  #   --zone "${ZONE}" \
  #   --cluster "${GKE_CLUSTER_NAME}"


  set +x
  echo "gke cluster created"
}

function delete_gke_cluster() {
  set -x

  for pn in "${DP_CTRL_POOLNAME}" "${DP_DRIVER_POOLNAME}" "${DP_EXEC_POOLNAME}" ; do
    gcloud container node-pools delete --quiet ${pn} \
      --zone ${ZONE} \
      --cluster ${GKE_CLUSTER_NAME}
  done

  gcloud container clusters delete --quiet ${GKE_CLUSTER_NAME} --zone ${ZONE}

  set +x
  echo "gke cluster deleted"
}

# https://cloud.google.com/dataproc/docs/guides/dpgke/dataproc-gke-nodepools#node_pool_settings
function create_dpgke_cluster() {
  set -x
  gcloud dataproc clusters gke create "${DPGKE_CLUSTER_NAME}" \
    --region=${REGION} \
    --gke-cluster=${GKE_CLUSTER} \
    --spark-engine-version=latest \
    --staging-bucket=${BUCKET} \
    --setup-workload-identity \
    --properties="spark:spark.kubernetes.container.image=${REGION}-docker.pkg.dev/${PROJECT_ID}/dockerfile-dataproc/dockerfile:latest" \
    --pools="name=${DP_CTRL_POOLNAME},roles=default,machineType=e2-standard-4" \
    --pools="name=${DP_DRIVER_POOLNAME},min=1,max=3,roles=spark-driver,machineType=n2-standard-4" \
    --pools="name=${DP_EXEC_POOLNAME},min=1,max=10,roles=spark-executor,machineType=n2-standard-8"
  set +x
  echo "dpgke cluster created"
}

function delete_dpgke_cluster() {
  set -x
  echo no such implementation
  set +x
}

source lib/database-functions.sh
source lib/net-functions.sh

function create_bucket () {
  if gsutil ls -b "gs://${BUCKET}" ; then
    echo "bucket already exists, skipping creation."
    return
  fi
  set -x
  gsutil mb -l ${REGION} gs://${BUCKET}
  set +x

  echo "==================="
  echo "Temp bucket created"
  echo "==================="

  # Copy initialization action scripts
  if [ -d init ]
  then
    set -x
    gsutil -m cp -r init/* gs://${BUCKET}/dataproc-initialization-actions
    set +x
  fi

  echo "==================="
  echo "init scripts copied"
  echo "==================="

}

function delete_bucket () {
  set -x
  gsutil -m rm -r gs://${BUCKET}
  set +x

  echo "bucket removed"
}

function create_autoscaling_policy() {
  set -x

  if gcloud dataproc autoscaling-policies describe ${AUTOSCALING_POLICY_NAME} --region ${REGION} > /dev/null 2>&1; then
    echo "policy ${AUTOSCALING_POLICY_NAME} already exists"
  else
    gcloud dataproc autoscaling-policies import ${AUTOSCALING_POLICY_NAME} --region ${REGION} --source autoscaling-policy.yaml
  fi
  set +x

  echo "autoscaling policy created"
}


function delete_autoscaling_policy() {
  set -x

  if gcloud dataproc autoscaling-policies describe ${AUTOSCALING_POLICY_NAME} --region ${REGION} > /dev/null; then
    gcloud dataproc autoscaling-policies delete --quiet ${AUTOSCALING_POLICY_NAME} --region ${REGION}
  else
    echo "policy ${AUTOSCALING_POLICY_NAME} does not exists"
  fi
  set +x

  echo "autoscaling policy created"
}

function reproduce {
  set -x
  # Run some job on the cluster which triggers the failure state
  # Spark?
  # Map/Reduce?
  # repro: steady load 15K containers
  # zero
  # containers finish
  # customer's use case increased to or above 55K pending containers
  # customer sustained load, increased, completed work, added more work
  # churns but stays high
  # as final work is completed
  # simulate gradual decrease of memory
  # simulate continued increase of containers until yarn pending memory reaches
  # When yarn pending memory should reach zero, it instead decreases below 0

  # https://linux.die.net/man/1/stress

  # consider dd if=/dev/zero | launch_job -

  set +x
}

function get_yarn_applications() {
  echo "not yet implemented"
}

function get_jobs_list() {

  if [[ -z ${JOBS_LIST} ]]; then
    JOBS_LIST="$(gcloud dataproc jobs list --region ${REGION} --format json)"
  fi

  echo "${JOBS_LIST}"
}


function diagnose {
  set -x
  local bdoss_path=${HOME}/src/bigdataoss-internal
  if [[ ! -d ${bdoss_path}/drproc ]]; then
    echo "mkdir -p ${bdoss_path} ; pushd ${bdoss_path} ; git clone sso://bigdataoss-internal/drproc ; popd"
    exit -1
  fi
  echo -n "This is going to take some time..."
  # --job-ids <comma separated Dataproc job IDs>
  # --yarn-application-ids <comma separated Yarn application IDs>
  # --stat-time & --end-time
  DIAGNOSE_CMD="gcloud dataproc clusters diagnose ${CLUSTER_NAME} --region ${REGION}"
  DIAG_OUT=$(${DIAGNOSE_CMD} 2>&1)
  echo "Done."

  DIAG_URL=$(echo $DIAG_OUT | perl -ne 'print if m{^gs://.*/diagnostic.tar.gz\s*$}')
  mkdir -p tmp
  gsutil cp -q ${DIAG_URL} tmp/

  if [[ ! -f venv/${CLUSTER_NAME}/pyvenv.cfg ]]; then
    mkdir -p venv/
    python3 -m venv venv/${CLUSTER_NAME}
    source venv/${CLUSTER_NAME}/bin/activate
    python3 -m pip install -r ${bdoss_path}/drproc/requirements.txt
  else
    source venv/${CLUSTER_NAME}/bin/activate
  fi

  python3 ${bdoss_path}/drproc/drproc.py tmp/diagnostic.tar.gz

  set +x
}

function execute_with_retries() {
  local -r cmd=$1
  for ((i = 0; i < 10; i++)); do
    if eval "$cmd"; then
      return 0
    fi
    sleep 5
  done
  return 1
}

function exists_bigtable_instance() {
  BIGTABLE_INSTANCES="$(gcloud bigtable instances list --format=json)"
  JQ_CMD=".[] | select(.name | test(\"${BIGTABLE_INSTANCE}$\"))"
  OUR_INSTANCE=$(echo ${BIGTABLE_INSTANCES} | jq -c "${JQ_CMD}")

  if [[ -z "${OUR_INSTANCE}" ]]; then
    return -1
  else
    return 0
  fi
}

function create_bigtable_instance() {
  set -x
  if exists_bigtable_instance == 0; then
    echo "bigtable instance already exists"
    set +x
    return 0
  fi

  gcloud bigtable instances create ${BIGTABLE_INSTANCE} \
    --display-name ${BIGTABLE_DISPLAY_NAME} \
    --cluster-config="${BIGTABLE_CLUSTER_CONFIG}"
  set +x
}

function delete_bigtable_instance() {
  set -x

  gcloud bigtable instances --quiet delete ${BIGTABLE_INSTANCE}

  set +x
}

function get_cluster_uuid() {
  get_cluster_json | jq -r .clusterUuid
}

function get_cluster_json() {
  #  get_clusters_list | jq ".[] | select(.name | test(\"${BIGTABLE_INSTANCE}$\"))"
  if [[ -z "${THIS_CLUSTER_JSON}" ]]; then
    JQ_CMD=".[] | select(.clusterName | contains(\"${CLUSTER_NAME}\"))"
    THIS_CLUSTER_JSON=$(get_clusters_list | jq -c "${JQ_CMD}")
  fi

  echo "${THIS_CLUSTER_JSON}"
}

function get_clusters_list() {
  if [[ -z ${CLUSTERS_LIST} ]]; then
    CLUSTERS_LIST="$(gcloud dataproc clusters list --region ${REGION} --format json)"
  fi

  echo "${CLUSTERS_LIST}"
}

# https://cloud.google.com/secret-manager/docs/create-secret-quickstart#secretmanager-quickstart-gcloud
# https://console.cloud.google.com/marketplace/product/google/secretmanager.googleapis.com?q=search&referrer=search&project=${PROJECT_ID}
function enable_secret_manager() {
  gcloud services enable \
    secretmanager.googleapis.com \
    --project=${PROJECT_ID}
}

function create_secret() {
  echo -n "super secret" | gcloud secrets create ${MYSQL_SECRET_NAME} \
    --replication-policy="automatic" \
    --data-file=-

}
