#!/bin/bash

gcloud dataproc clusters create $CLUSTER --properties "yarn:yarn.nodemanager.vmem-check-enabled=false" --zone us-west1-c --master-machine-type n1-standard-8 --master-boot-disk-size 500 --num-workers 4 --worker-machine-type n1-standard-4 --worker-boot-disk-size 500 --project cloudml-spark-tf-connector
