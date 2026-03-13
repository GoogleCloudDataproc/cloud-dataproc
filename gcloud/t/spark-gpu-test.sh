#!/bin/bash
source lib/env.sh
set -x
APPLICATION_BUCKET="${BUCKET}"

# Upload verification scripts
echo "Copying verification scripts to -m node..."
bin/scp-m t/scripts

# Run Python verification scripts on -m node
echo "Running Python GPU verification scripts..."
gcloud compute ssh --zone ${ZONE} ${CLUSTER_NAME}-m \
  --project ${PROJECT_ID} \
  --command "source /opt/conda/default/etc/profile.d/conda.sh && conda activate dpgce && \
echo '--- TensorFlow ---' && \
time python3 /tmp/scripts/verify_tensorflow.py && \
echo '--- PyTorch ---' && \
time python3 /tmp/scripts/verify_torch.py"

echo "Proceeding with Spark GPU tests..."

#gsutil cp test.py gs://${BUCKET}/

echo gcloud dataproc jobs submit pyspark \
  --properties="spark:spark.executor.resource.gpu.amount=1" \
  --properties="spark:spark.task.resource.gpu.amount=1" \
  --properties="spark.executorEnv.YARN_CONTAINER_RUNTIME_DOCKER_IMAGE=${YARN_DOCKER_IMAGE}" \
  --cluster=${CLUSTER_NAME} \
  --region ${REGION} gs://${BUCKET}/test.py

get_gpu_resources_script="/usr/lib/spark/scripts/gpu/getGpusResources.sh"
echo gcloud dataproc jobs submit spark \
  --project "${PROJECT_ID}" \
  --cluster="${CLUSTER_NAME}" \
  --region "${REGION}" \
  --jars "file:///usr/lib/spark/examples/jars/spark-examples.jar" \
  --class "org.apache.spark.examples.ml.JavaIndexToStringExample" \
  --properties \
"spark.driver.resource.gpu.amount=1,"\
"spark.driver.resource.gpu.discoveryScript=${get_gpu_resources_script},"\
"spark.executor.resource.gpu.amount=1,"\
"spark.executor.resource.gpu.discoveryScript=${get_gpu_resources_script}"

set -e

#
# Run SparkPi examples with different parameters
#
time gcloud dataproc jobs submit spark \
  --cluster "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --class org.apache.spark.examples.SparkPi \
  --jars file:///usr/lib/spark/examples/jars/spark-examples.jar \
  -- 1000

time gcloud dataproc jobs submit spark \
  --cluster "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --class org.apache.spark.examples.SparkPi \
  --jars file:///usr/lib/spark/examples/jars/spark-examples.jar \
  --properties \
"spark.executor.resource.gpu.amount=1,"\
"spark.executor.cores=6,"\
"spark.executor.memory=4G,"\
"spark.plugins=com.nvidia.spark.SQLPlugin,"\
"spark.executor.resource.gpu.discoveryScript=${get_gpu_resources_script},"\
"spark.dynamicAllocation.enabled=false,"\
"spark.sql.autoBroadcastJoinThreshold=10m,"\
"spark.sql.files.maxPartitionBytes=512m,"\
"spark.task.resource.gpu.amount=0.333,"\
"spark.task.cpus=2,"\
"spark.yarn.unmanagedAM.enabled=false" \
-- 1000

time gcloud dataproc jobs submit spark \
  --cluster "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --class org.apache.spark.examples.SparkPi \
  --jars file:///usr/lib/spark/examples/jars/spark-examples.jar \
  --properties \
"spark.driver.resource.gpu.amount=1,"\
"spark.driver.resource.gpu.discoveryScript=${get_gpu_resources_script},"\
"spark.executor.resource.gpu.amount=1,"\
"spark.executor.resource.gpu.discoveryScript=${get_gpu_resources_script}"\
  -- 1000

#
# Run JavaIndexToStringExample with different parameters
#
time gcloud dataproc jobs submit spark \
  --cluster "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --class org.apache.spark.examples.ml.JavaIndexToStringExample \
  --jars file:///usr/lib/spark/examples/jars/spark-examples.jar

time gcloud dataproc jobs submit spark \
  --cluster "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --class org.apache.spark.examples.ml.JavaIndexToStringExample \
  --jars file:///usr/lib/spark/examples/jars/spark-examples.jar \
  --properties \
"spark.executor.resource.gpu.amount=1,"\
"spark.executor.cores=6,"\
"spark.executor.memory=4G,"\
"spark.plugins=com.nvidia.spark.SQLPlugin,"\
"spark.executor.resource.gpu.discoveryScript=${get_gpu_resources_script},"\
"spark.dynamicAllocation.enabled=false,"\
"spark.sql.autoBroadcastJoinThreshold=10m,"\
"spark.sql.files.maxPartitionBytes=512m,"\
"spark.task.resource.gpu.amount=0.333,"\
"spark.task.cpus=2,"\
"spark.yarn.unmanagedAM.enabled=false"

time gcloud dataproc jobs submit spark \
  --cluster "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --class=org.apache.spark.examples.ml.JavaIndexToStringExample \
  --jars file:///usr/lib/spark/examples/jars/spark-examples.jar \
  --properties \
"spark.driver.resource.gpu.amount=1,"\
"spark.driver.resource.gpu.discoveryScript=${get_gpu_resources_script},"\
"spark.executor.resource.gpu.amount=1,"\
"spark.executor.resource.gpu.discoveryScript=${get_gpu_resources_script}"

set +x
