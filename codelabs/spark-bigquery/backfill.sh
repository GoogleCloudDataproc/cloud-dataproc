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

# This script is associated with the codelab found at <url>. This kicks off a 
# series of Cloud Dataproc PySpark Jobs.

# Starting year and all months
base_year=2016
months=(01 02 03 04 05 06 07 08 09 10 11 12)

# Grab list of existing BigQuery tables
tables=$(bq ls fh-bigquery:reddit_posts) 

year=${base_year}

# Iterate for every year / month pair starting from January 2016 up through the current year.
while [[ ${year} -le $(date +%Y) ]]
do}
  for month in "${months[@]}"
  do
      # If the YYYY_MM table doesn't exist, we skip over it.
      exists="$(echo "${tables}" | grep " ${year}_${month} ")"
      if [ -z "${exists}" ]; then
        continue
      fi
      
      # Submit a PySpark job via the Cloud Dataproc Jobs API
      gcloud dataproc jobs submit pyspark \
        --cluster ws-spark-7 \ 
        --jars gs://spark-lib/bigquery/spark-bigquery-latest.jar \ # Provide path to jar for the spark-bigquery-connector
        --driver-log-levels root=FATAL \ # Suppress all non-fatal logs
        backfill.py \ # Local Python script to execute
        -- ${year} ${month} & # These are passed into the Python script
      sleep 5 
  done
  ((year ++))
done