#!/usr/bin/env bash

# This init action installs bigbench benchmark tool on a dataproc cluster

set -euxo pipefail

function install_components(){
  apt-get install -y python-pip
  pip install --upgrade google-cloud-storage
  apt-get install -y pssh
}

function install_bigbench(){
  local benchmark_engine
  benchmark_engine="$(/usr/share/google/get_metadata_value attributes/benchmark_engine || true)"
  git clone https://github.com/takeon8/Big-Data-Benchmark-for-Big-Bench
  cd Big-Data-Benchmark-for-Big-Bench
  if [ "${benchmark_engine}" == 'spark_sql' ]  ; then
    git checkout spark-sql
    if [[ "${dataproc_version}" == 'dataproc-1-3' ]] ; then
      # On Dataproc 1.3 we need to provide updated bigbench-ml-spark-2x.jar
      git cherry-pick d543e9a748a6a17524c7420726f3dbb6bc19c108
    fi

    if ! grep -q '^spark\.sql\.warehouse\.dir=' '/etc/spark/conf/spark-defaults.conf'; then
      echo 'spark.sql.warehouse.dir=/root/spark-warehouse' >> '/etc/spark/conf/spark-defaults.conf'
    fi
  else
    git checkout spark2
  fi
}

function configure_bigbench(){
  local old_hadoop_conf='export BIG_BENCH_HADOOP_CONF="/etc/hadoop/conf.cloudera.hdfs"'
  local new_hadoop_conf='export BIG_BENCH_HADOOP_CONF="/etc/hadoop/conf"'
  local old_libs='export BIG_BENCH_HADOOP_LIBS_NATIVE="/opt/cloudera/parcels/CDH/lib/hadoop/lib/native"'
  local new_libs='export BIG_BENCH_HADOOP_LIBS_NATIVE=...'

  sed -i "s#${old_hadoop_conf}#${new_hadoop_conf}#" conf/userSettings.conf
  sed -i "s#${old_libs}#${new_libs}#" conf/userSettings.conf
  sed -i "s/export BIG_BENCH_PSSH_BINARY=\"pssh\"/export BIG_BENCH_PSSH_BINARY=\"parallel-ssh\"/g" \
    conf/userSettings.conf

  echo 'IS_EULA_ACCEPTED=true' >> \
    data-generator/Constants.properties
  echo 'export BIG_BENCH_ENGINE_HIVE_ML_FRAMEWORK_SPARK_BINARY="spark-submit --deploy-mode cluster --master yarn"' >> \
    engines/hive/conf/engineSettings.conf
}

function set_system_properties(){
  local file_handle_limit
  file_handle_limit="$(/usr/share/google/get_metadata_value attributes/file_handle_limit || true)"
  local swap_size
  swap_size="$(/usr/share/google/get_metadata_value attributes/swap_size || true)"

  if [ "${file_handle_limit}" != '' ]  ; then
    echo "${file_handle_limit}" > /proc/sys/fs/file-max
  fi

  if [ "${swap_size}" != '' ]  ; then
    fallocate -l "${swap_size}" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
  fi
}



function main(){
  local role
  role="$(/usr/share/google/get_metadata_value attributes/dataproc-role)"
  local dataproc_version
  dataproc_version="$(/usr/share/google/get_metadata_value image | grep -o 'dataproc-[0-9]-[0-9]' )"

  if [[ "${role}" == 'Master' ]] ; then
    install_bigbench
    configure_bigbench
    install_components
  fi
  set_system_properties
}

main
