"""
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
"""

import datetime
import os, configparser

from airflow import models
from airflow.exceptions import AirflowFailException
from airflow.providers.google.cloud.operators import dataproc
from airflow.utils import dates

pwd = os.path.dirname(os.path.abspath(__file__))

# Read configuration variables
def read_configuration(config_file_path):
  full_path = os.path.join(pwd, config_file_path)
  config = configparser.ConfigParser(interpolation=None)
  config.optionxform = str
  try:
    config.read(full_path)
    return config
  except configparser.Error as exc:
    raise AirflowFailException(exc)

config = read_configuration("config/c_batch_serverless.ini")

BATCH_ID = config['COMPOSER']['DAG_NAME'] + "-" + datetime.datetime.now().strftime("%m-%d-%Y-%H-%M")

# Spark Arguments
spark_args = []
for arg, value in config.items('SPARK'):
  spark_args.append("--" + arg + "=" + value)

# https://cloud.google.com/python/docs/reference/dataproc/latest/google.cloud.dataproc_v1.types.Batch
batch_config = {
    'name': 'projects/{}/regions/{}/batches/{}'.format(models.Variable.get('PROJECT_ID'), models.Variable.get('REGION'), BATCH_ID),
    'spark_batch': {
        'main_jar_file_uri': config['DATAPROC']['SPARK_APP_PATH'],
        'args': spark_args
    },
    'environment_config': {
        'execution_config': {
            'network_uri': config['DATAPROC']['NETWORK'],
            'subnetwork_uri': config['DATAPROC']['SUBNETWORK']
        }
    }
}

# DAG arguments
default_dag_args = {
    'start_date': dates.days_ago(1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': int(config['COMPOSER']['RETRIES']),
    'execution_timeout': datetime.timedelta(seconds=int(config['COMPOSER']['EXEC_TIMEOUT'])),
    'dagrun_timeout': datetime.timedelta(seconds=int(config['COMPOSER']['RUN_TIMEOUT'])),
    'retry_delay': datetime.timedelta(seconds=int(config['COMPOSER']['RETRY_DELAY'])),
    'project_id': models.Variable.get('PROJECT_ID'),
    'region': models.Variable.get('REGION')
}

# Get schedule interval
schedule_interval = datetime.timedelta(days=int(config['COMPOSER']['SCHEDULE_DAYS']), hours=int(config['COMPOSER']['SCHEDULE_HOURS']))

# Create DAG
with models.DAG(
    config['COMPOSER']['DAG_NAME'],
    schedule_interval=schedule_interval,
    default_args=default_dag_args) as dag:

  # Run Dataproc Serverless
  run_dataproc_serverless = dataproc.DataprocCreateBatchOperator(
      task_id='run_dataproc_serverless',
      batch=batch_config,
      batch_id=BATCH_ID,
      project_id=models.Variable.get('PROJECT_ID'),
      timeout=int(config['DATAPROC']['TIMEOUT'])
  )

  # Define DAG dependencies.
  run_dataproc_serverless
