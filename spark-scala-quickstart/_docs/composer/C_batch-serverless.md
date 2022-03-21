## Cloud Composer - Dataproc Serverless

This session guides you to create an Apache Airflow DAG in GCP Cloud Composer.  
This example runs a job using Dataproc Serverless.  
Batch job example used: [GCS to GCS](../dataproc/2_batch-gcs-gcs.md).  
The DAG used in this guide is located [here](../../composer/src/dags/c_batch_serverless.py).  

### Step 1 - Setup GCP Environment Variables (to Airflow)

```console
export PROJECT_ID="your_project_id"
export REGION="your_region"
```

### Step 2 - Setup Composer Variables

```console
export COMPOSER_ENV="your_composer-env"
export COMPOSER_LOCATION=${REGION}
```

### Step 3 - Setup DAG specific config

Update the [composer/src/dags/config/c_batch_serverless.ini](../../composer/src/dags/config/c_batch_serverless.ini) to your desired config values, read by the python file.

### Step 4  - Create a Composer Environment (skip if it is already created)

Follow the [instructions](https://cloud.google.com/composer/docs/composer-2/create-environments) to create a Composer Environment.

### Step 5 - Set Composer Airflow variables

```console
export AIRFLOW_VARIABLE="gcloud composer environments run ${COMPOSER_ENV} \
                            --location ${COMPOSER_LOCATION} variables -- set"

$AIRFLOW_VARIABLE PROJECT_ID "${PROJECT_ID}" && \
$AIRFLOW_VARIABLE REGION "${REGION}"
```

### Step 6 - Push the local python and conf files to DAGs folder

```console
export LOCAL_DAG_PYTHON="composer/src/dags/c_batch_serverless.py"
export LOCAL_DAG_CONFIG="composer/src/dags/config/c_batch_serverless.ini"

export DAGs_FOLDER=$(gcloud composer environments describe $COMPOSER_ENV \
  --location $REGION \
  --format="get(config.dagGcsPrefix)")

gsutil cp $LOCAL_DAG_PYTHON $DAGs_FOLDER/
gsutil cp $LOCAL_DAG_CONFIG $DAGs_FOLDER/config/
```

### Result

The job will run as scheduled, running the Spark job with Dataproc Serverless.

### Code Snippets
All code snippets within this document are provided under the following terms.
```
Copyright 2022 Google. This software is provided as-is, without warranty or representation for any use or purpose. Your use of it is subject to your agreement with Google. 
```