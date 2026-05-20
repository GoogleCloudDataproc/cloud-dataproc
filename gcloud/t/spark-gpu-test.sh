#!/bin/bash
source lib/env.sh
set -euo pipefail

MASTER_NODE="${CLUSTER_NAME}-m"

echo "--- Verifying GPU on cluster: ${CLUSTER_NAME}, Project: ${PROJECT_ID}, Zone: ${ZONE} ---"

# Function to run a command on the master node via SSH
run_ssh_command() {
  local cmd="$1"
  local desc="$2"
  echo "--- Running: ${desc} ---"
  gcloud compute ssh "${MASTER_NODE}" --project "${PROJECT_ID}" --zone "${ZONE}" --command "${cmd}" -- -o StrictHostKeyChecking=no -o ConnectTimeout=60
  if [[ $? -ne 0 ]]; then
    echo "--- FAILED: ${desc} ---"
    exit 1
  else
    echo "--- SUCCESS: ${desc} ---"
  fi
  echo ""
}

# 1. Set NUMA Nodes
NUMA_CMD=$(cat <<'EOF'
sudo bash -c '
NODES=$(ls /sys/module/nvidia/drivers/pci:nvidia/*/numa_node 2>/dev/null)
if [ -n "$NODES" ]; then
  for f in $NODES; do
    chmod a+rw "$f" && echo 0 > "$f"
  done
  echo "NUMA nodes set."
else
  echo "No NUMA nodes found to set."
fi
'
EOF
)
run_ssh_command "${NUMA_CMD}" "Set NUMA nodes"

# 2. NVIDIA SMI
run_ssh_command "nvidia-smi" "NVIDIA SMI"

# 3. PyTorch Test
PYTORCH_CMD=$(cat <<'EOF'
source /opt/conda/default/etc/profile.d/conda.sh && conda activate pytorch && python -c '
import torch
cuda_available = torch.cuda.is_available()
print(f"PyTorch CUDA Available: {cuda_available}")
if not cuda_available: exit(1)
print("PyTorch GPU Name:", torch.cuda.get_device_name(0))
'
EOF
)
run_ssh_command "${PYTORCH_CMD}" "PyTorch CUDA Check"

# 4. TensorFlow Test
TENSORFLOW_CMD=$(cat <<'EOF'
source /opt/conda/default/etc/profile.d/conda.sh && conda activate tensorflow && python -c '
import tensorflow as tf
print("TensorFlow GPU Details : ")
print(tf.config.list_physical_devices("GPU"))
gpu_available = tf.config.list_physical_devices("GPU")
print("gpu_available : " + str(gpu_available))
if not gpu_available: exit(1)
from tensorflow.python.client import device_lib
print(device_lib.list_local_devices())
'
EOF
)
run_ssh_command "${TENSORFLOW_CMD}" "TensorFlow GPU Check"

# 5. GPU Agent Status
run_ssh_command "systemctl status gpu-utilization-agent.service" "GPU Agent Status"

# 6. NVCC Version
NVCC_CMD='
find /usr/local -type d -name "cuda-1*" | while read cuda_path; do
  if [[ -x "${cuda_path}/bin/nvcc" ]]; then
    echo "Found NVCC in ${cuda_path}"
    "${cuda_path}/bin/nvcc" --version
  fi
done
'
run_ssh_command "${NVCC_CMD}" "NVCC Version Check"

# 7. CUDNN Check
run_ssh_command "sudo ldconfig -v 2>/dev/null | grep libcudnn" "CUDNN Library Check"

echo "--- Node-level GPU checks complete ---"

echo "Proceeding with Spark GPU tests..."

set -x

get_gpu_resources_script="/usr/lib/spark/scripts/gpu/getGpusResources.sh"

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
"spark.yarn.unmanagedAM.enabled=false"\

time gcloud dataproc jobs submit spark \
  --cluster "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --class=org.apache.spark.examples.ml.JavaIndexToStringExample \
  --jars file:///usr/lib/spark/examples/jars/spark-examples.jar \
  --properties \
"spark.driver.resource.gpu.amount=1,"\
"spark.driver.resource.gpu.discoveryScript=${get_gpu_resources_script},"\
"spark.executor.resource.gpu.amount=1,"\
"spark.executor.resource.gpu.discoveryScript=${get_gpu_resources_script}"\

set +x
echo "--- Spark GPU tests complete ---"
