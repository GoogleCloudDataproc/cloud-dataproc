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

import pytest

from test_util.helper_functions import assert_dag_dict_equal
from airflow.models import DagBag

@pytest.fixture()
def dagbag():
  return DagBag(include_examples=False)

@pytest.fixture()
def dag(dagbag):
  return dagbag.get_dag(dag_id="c_batch_serverless")

def test_num_tasks(dag):
  assert len(dag.tasks) == 1

def test_tasks_order(dag):
  assert_dag_dict_equal(
      {
          "run_dataproc_serverless": []
      },
      dag
  )