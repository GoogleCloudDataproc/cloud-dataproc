## Cloud Composer - Import from GCS to BQ

This session guides you on how to import data from GCS to BQ from an Apache Airflow DAG in GCP Cloud Composer.

### Step 1 - Follow the other guide before Step 2

Follow the [Composer Batch Submit](A_batch-submit-cluster.md) guide, which sets up the [DAG](../../composer/src/dags/a_batch_submit_cluster.py) that runs the [Batch GCS to GCS](../dataproc/2_batch-gcs-gcs.md) example

### Step 2 - Add the following additional task in the [DAG](../../composer/src/dags/a_batch_submit_cluster.py)

```console
from airflow.operators import bash

BQ_DATASET=your_dataset
BQ_TABLE=your_table
BUCKET=your_bucket
SRC_PARQUET_DATA=BUCKET+"/your_data_path/*.parquet"
PARTITION=your_bq_table_partition_field

# Load data from GCS to BQ
load_from_gcs_to_bq = bash.BashOperator(
    task_id='load_from_gcs_to_bq',
    bash_command=f'bq load --replace --source_format=PARQUET --time_partitioning_field={PARTITION} {BQ_DATASET}.{BQ_TABLE} {SRC_PARQUET_DATA}')
        
# The --replace flag overwrites if table already exists.
```

### Result

The added task will make Airflow load the .parquet data from the provided GCS path to a BQ table.

### Code Snippets
All code snippets within this document are provided under the following terms.
```
Copyright 2022 Google. This software is provided as-is, without warranty or representation for any use or purpose. Your use of it is subject to your agreement with Google. 
```