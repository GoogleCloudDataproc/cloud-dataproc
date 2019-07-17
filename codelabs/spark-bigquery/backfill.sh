#!/bin/bash

# Copyright 2019 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script is associated with the codelab found at https://codelabs.developers.google.com/codelabs/pyspark-bigquery/. 
# This script kicks off a series of Cloud Dataproc PySpark Jobs.
# This script must be provided with a Cloud Dataproc Cluster name and Bucket name in positions arguments 1 and 2 respectively.

# Starting year and all months
base_year=2016
months=(01 02 03 04 05 06 07 08 09 10 11 12)

# Grab list of existing BigQuery tables
tables=$(bq ls fh-bigquery:reddit_posts) 

year=${base_year}
warm_up=true 

# Set the name of the output bucket
CLUSTER_NAME=${1}
BUCKET_NAME=${2}

# Iterate for every year / month pair starting from January 2016 up through the current year.
while [[ ${year} -le $(date +%Y) ]]
do
  for month in "${months[@]}"
  do
    # If the YYYY_MM table doesn't exist, we skip over it.
    exists="$(echo "${tables}" | grep " ${year}_${month} ")"
    if [ -z "${exists}" ]; then
      continue
    fi
    echo "${year}_${month}"

    # Submit a PySpark job via the Cloud Dataproc Jobs API
    gcloud dataproc jobs submit pyspark \
        --cluster ${CLUSTER_NAME} \
        --jars gs://spark-lib/bigquery/spark-bigquery-latest.jar \
        --driver-log-levels root=FATAL \
        backfill.py \
        -- ${year} ${month} ${BUCKET_NAME} &
    sleep 5

    if ${warm_up}; then 
      sleep 10
      warm_up=false 
    fi
  done
  ((year ++))
done
