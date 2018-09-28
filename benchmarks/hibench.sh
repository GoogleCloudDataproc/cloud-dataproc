#!/usr/bin/env bash

function err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
  return 1
}

function install_dependencies(){
    apt-get -y install bc || err 'Unable to install bc'
    git clone https://github.com/takeon8/HiBench
    wget -qO- http://archive.apache.org/dist/maven/maven-3/3.5.4/binaries/apache-maven-3.5.4-bin.tar.gz \
      | tar zxv
    export M2_HOME=/apache-maven-3.5.4
    echo "PATH=/apache-maven-3.5.4/bin:$PATH" >> /etc/profile
    update-alternatives --install "/usr/bin/mvn" "mvn" "/apache-maven-3.5.4/bin/mvn" 0
    update-alternatives --set mvn /apache-maven-3.5.3/bin/mvn
    echo 'export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64' >> /etc/hadoop/conf/hadoop-env.sh
}

function configure_benchmark(){
    local namenode=$(bdconfig get_property_value \
      --configuration_file '/etc/hadoop/conf/core-site.xml' \
      --name 'fs.default.name')
    local cluster_name=$(echo "${namenode}" | replace 'hdfs://' '')
    local num_masters=$(/usr/share/google/get_metadata_value attributes/dataproc-master \
      | grep -o "${cluster_name%%-*}" \
      | wc -l)
    local num_masters_additional=$(/usr/share/google/get_metadata_value \
      attributes/dataproc-master-additional \
      | grep -o "${cluster_name%%-*}" \
      | wc -l)
    local master_cpus=$(nproc -all)
    local num_workers=$(/usr/share/google/get_metadata_value attributes/dataproc-worker-count)
    local name=$(/usr/share/google/get_metadata_value name)
    local workers_list=$(yarn node -list -all | grep "${name%%-*}-w-0")
    local worker_id=$(echo "${workers_list%%:*}")
    local worker_cpus=$(yarn node -list -showDetails ${worker_id} \
      | grep -m1 vCores \
      | sed -e 's/vCores:\(.*\)>/\1/' \
      | sed 's/.*,//' \
      | tr -d '[:space:]')
    sed -i '/micro.sleep/d' ./HiBench/conf/benchmarks.lst
    cat << 'EOF' > ./HiBench/conf/hadoop.conf
    # Hadoop home
    hibench.hadoop.home     /usr/lib/hadoop

    # The path of hadoop executable
    hibench.hadoop.executable     ${hibench.hadoop.home}/bin/hadoop

    # Hadoop configraution directory
    hibench.hadoop.configure.dir  ${hibench.hadoop.home}/etc/hadoop

    # Hadoop release provider. Supported value: apache, cdh5, hdp
    hibench.hadoop.release    apache

    hibench.hadoop.examples.test.jar    /usr/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar
EOF
    echo "# The root HDFS path to store HiBench data" >> ./HiBench/conf/hadoop.conf
    echo "hibench.hdfs.master       ${namenode}:8020" >> ./HiBench/conf/hadoop.conf
    cat << 'EOF' > ./HiBench/conf/spark.conf
    # Spark home
    hibench.spark.home      /usr/lib/spark

    # Spark master
    #   standalone mode: spark://xxx:7077
    #   YARN mode: yarn-client
    hibench.spark.master    yarn-client
EOF
    yarn_executors_num=$(python -c \
        "print (${num_masters} + ${num_masters_additional}) * ${master_cpus} + ${num_workers} * ${worker_cpus}")
    echo -e "export YARN_NUM_EXECUTORS=${yarn_executors_num}\n$(cat /HiBench/bin/functions/workload_functions.sh)" \
      > /HiBench/bin/functions/workload_functions.sh
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


function main() {
  local role=$(/usr/share/google/get_metadata_value attributes/dataproc-role)
  local master=$(/usr/share/google/get_metadata_value attributes/dataproc-master)
  if [[ "${role}" == 'Master' ]]; then
    # Only run on the master node
    update_apt_get || err 'Unable to update apt-get'
    install_dependencies || err 'Installing dependencies for HiBench failed'
    configure_benchmark || err 'Configuration failed'
    bash ./HiBench/bin/build_all.sh || echo "Retry build step" && \
      bash ./HiBench/bin/build_all.sh \
      || err "Build step failed"
  fi
  set_system_properties
}

main

