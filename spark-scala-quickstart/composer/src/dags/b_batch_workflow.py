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
import yaml

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

config = read_configuration("config/b_batch_workflow.ini")

# Read workflow template
def read_workflow_template(template_path):
  full_path = os.path.join(pwd, template_path)
  with open(full_path, 'r') as stream:
    try:
      return yaml.safe_load(stream)
    except yaml.YAMLError as exc:
      raise AirflowFailException(exc)

workflow_template = read_workflow_template("config/batch-gcs-gcs-workflow.yaml")

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

  # Instantiate a Dataproc Workflow
  run_dataproc_workflow = dataproc.DataprocInstantiateInlineWorkflowTemplateOperator(
      task_id='run_dataproc_workflow',
      template=workflow_template
  )

  # Define DAG dependencies.
  run_dataproc_workflow