## Example Options & Metadata

```bash
#    --metadata include-pytorch=1
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
#    --image "projects/${PROJECT_ID}/global/images/nvidia-open-kernel-bookworm-2024-06-26" \
#    --image "projects/${PROJECT_ID}/global/images/nvidia-open-kernel-bookworm-2024-06-21-a" \
```

## GPU Specific

```bash
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
```

## Hue

```bash
#    --image https://www.googleapis.com/compute/v1/projects/cloud-dataproc-ci/global/images/dataproc-2-0-debian10-20240314-212221-rc99 \
#    --initialization-actions "${INIT_ACTIONS_ROOT}/hue/hue.sh" \
#     --metadata startup-script-url="${INIT_ACTIONS_ROOT}/delay-masters-startup.sh" \
```

## DASK rapids

```bash
    # --metadata rapids-runtime=DASK \
    # --metadata cuda-version="${CUDA_VERSION}" \
    # --metadata rapids-version="22.04" \
    # --initialization-actions ${INIT_ACTIONS_ROOT}/gpu/install_gpu_driver.sh,${INIT_ACTIONS_ROOT}/rapids/rapids.sh \
```

## Bigtable

```bash
    # --initialization-actions "${INIT_ACTIONS_ROOT}/bigtable/bigtable.sh" \
    # --metadata bigtable-instance=${BIGTABLE_INSTANCE} \
    # --initialization-action-timeout=15m \
```

## Oozie

```bash
#    --metadata startup-script-url="${INIT_ACTIONS_ROOT}/delay-masters-startup.sh" \
#    --initialization-actions "${INIT_ACTIONS_ROOT}/oozie/oozie.sh" \
#    --properties "dataproc:dataproc.master.custom.init.actions.mode=RUN_AFTER_SERVICES" \
```

## Livy

```bash
#    --initialization-actions "${INIT_ACTIONS_ROOT}/livy/livy.sh" \
```

## Complex Init Actions

```bash
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
```

## Serial Init Actions

```bash
# [serial] new initialization action to execute in serial #1086
# https://github.com/GoogleCloudDataproc/initialization-actions/pull/1086
#    --initialization-actions ${INIT_ACTIONS_ROOT}/serial/serial.sh \
#    --metadata "initialization-action-paths=${INIT_ACTION_PATHS}" \
#    --metadata "initialization-action-paths-separator=${PATH_SEPARATOR}" \
```

## Worker Configs

```bash
    # --worker-boot-disk-type pd-ssd \
    # --worker-boot-disk-size 50 \
    # --worker-machine-type ${MACHINE_TYPE} \
    # --num-masters=3 \
    # --num-workers=3 \
```

## Spark BigQuery Connector

```bash
  #    --metadata spark-bigquery-connector-version=0.31.1 \
```

## NVidia Docker on Yarn

```bash
#    --metadata yarn-docker-image=${YARN_DOCKER_IMAGE} \
#    --optional-components DOCKER \
#    --initialization-actions ${INIT_ACTIONS_ROOT}/kernel/upgrade-kernel.sh \
#    --initialization-actions ${INIT_ACTIONS_ROOT}/util/upgrade-kernel.sh,${INIT_ACTIONS_ROOT}/gpu/install_gpu_driver.sh,${INIT_ACTIONS_ROOT}/nvidia_docker.sh \
```

## Other Components

```bash
#    --optional-components PRESTO \
#    --optional-components HBASE,ZOOKEEPER \
#    --optional-components FLINK \
```

## Properties File

```bash
# --properties-file=${INIT_ACTIONS_ROOT}/dataproc.properties
```

## Startup Scripts

```bash
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
```