#!/bin/bash

# Copyright 2017 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script makes the following assumptions:
# 1. gcloud is configured with credentials that have been set up to run these
#    tests.
# 2. This means that the credentials should provide access to a GCS bucket
#    containing the data required to run the tests.
# 3. The path to this GCS bucket will be provided using the GCS_BUCKET
#    environment variable.
# 4. The path will be provided prefixed with a "gs://" and will have no trailing
#    backslash.
# 5. The GCS bucket will contain a /preprocessed-data subpath containing the
#    files and subdirectories in the ../trainer/tests directory (path relative
#    to this file).

DATA_DIR="$GCS_BUCKET/preprocessed-data"
ARTIFACTS_DIR="$DATA_DIR/artifacts"

TEST_TIME=$(date +%s)
JOB_NAME=test_job_$TEST_TIME
JOB_DIR="$GCS_BUCKET/$JOB_NAME"
JOB_CONFIG="gcloud-tests/config.yaml"

REGION="us-central1"


echo "Submitting training job..."

gcloud ml-engine jobs submit training $JOB_NAME \
  --runtime-version=1.2 \
  --job-dir=$JOB_DIR \
  --module-name=trainer.task \
  --package-path trainer \
  --region $REGION \
  --config=$JOB_CONFIG \
  --quiet \
  -- \
  --data-format=tsv \
  --train-dir=${DATA_DIR}/ \
  --eval-dir=${DATA_DIR}/ \
  --artifact-dir=${ARTIFACTS_DIR}/ \
  --batch-size=2 \
  --train-steps=10 \
  --eval-steps=1 \
  --learning-rate=0.5 \
  --min-eval-frequency=0

while :
do
  sleep 30
  echo "Polling ML Engine for status of training job: $JOB_NAME"
  STATUS=$(gcloud ml-engine jobs list --filter="jobId=$JOB_NAME" --format="value(state)")
  echo "Status: $STATUS"
  if [[ $STATUS == "SUCCEEDED" || $STATUS == "FAILED" ]]; then
    break
  fi
done

if [[ $STATUS != "SUCCEEDED" ]]; then
  exit 1
fi


MODEL_NAME=test_model
MODEL_VERSION=v$TEST_TIME

ORIGIN=$(gsutil ls "$JOB_DIR/**/saved_model.pb" | sed 's/\(.\)saved_model.pb/\1/g')

echo "Training succeeded. Creating model from saved model at $ORIGIN ..."

gcloud ml-engine versions create $MODEL_VERSION \
  --model=$MODEL_NAME \
  --origin=$ORIGIN \
  --runtime-version=1.2

gcloud ml-engine predict \
  --model $MODEL_NAME \
  --version $MODEL_VERSION \
  --json-instances ./gcloud-tests/request.json
