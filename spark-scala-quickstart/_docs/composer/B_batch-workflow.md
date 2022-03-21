## Cloud Composer - Dataproc Workflow

This session guides you to create an Apache Airflow DAG in GCP Cloud Composer.   
This example runs a job using Dataproc Workflow.  
Batch job example used: [GCS to GCS](../dataproc/2_batch-gcs-gcs.md).  
The DAG used in this guide is located [here](../../composer/src/dags/b_batch_workflow.py).

### Step 1 - Setup GCP Environment Variables

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

Update the [composer/src/dags/config/b_batch_workflow.ini](../../composer/src/dags/config/b_batch_workflow.ini) to your desired config values, read by the python file.

Copy the workflow template from dataproc folder to the composer folder:
```console
cp dataproc/batch-gcs-gcs/gcp-dataproc-workflow/batch-gcs-gcs-workflow.yaml composer/src/dags/config/batch-gcs-gcs-workflow.yaml
```

### Step 4  - Create a Composer Environment (skip if it is already created)

Follow the [instructions](https://cloud.google.com/composer/docs/composer-2/create-environments) to create a Composer Environment.

### Step 6 - Install python dependencies

```
gcloud composer environments update ${COMPOSER_ENV} \
          --update-pypi-package pyyaml \
          --location ${COMPOSER_LOCATION}
```

### Step 7 - Set Composer Airflow variables

```console
export AIRFLOW_VARIABLE="gcloud composer environments run ${COMPOSER_ENV} \
                            --location ${COMPOSER_LOCATION} variables -- set"

$AIRFLOW_VARIABLE PROJECT_ID "${PROJECT_ID}" && \
$AIRFLOW_VARIABLE REGION "${REGION}"
```

### Step 8 - Push the local python, conf and yaml files to DAGs folder

```console
export LOCAL_DAG_PYTHON="composer/src/dags/b_batch_workflow.py"
export LOCAL_DAG_CONFIG="composer/src/dags/config/c_batch_workflow.ini"
export LOCAL_DAG_WORKFLOW="composer/src/dags/config/batch-gcs-gcs-workflow.yaml"

export DAGs_FOLDER=$(gcloud composer environments describe $COMPOSER_ENV \
  --location $COMPOSER_LOCATION \
  --format="get(config.dagGcsPrefix)")

gsutil cp $LOCAL_DAG_PYTHON $DAGs_FOLDER/
gsutil cp $LOCAL_DAG_CONFIG $DAGs_FOLDER/config/
gsutil cp $LOCAL_DAG_WORKFLOW $DAGs_FOLDER/config/
```

### Result

The job will run as scheduled, running a Dataproc Workflow.

### Code Snippets
All code snippets within this document are provided under the following terms.
```
Copyright 2022 Google. This software is provided as-is, without warranty or representation for any use or purpose. Your use of it is subject to your agreement with Google. 
```