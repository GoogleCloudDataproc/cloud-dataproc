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

# https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html
def assert_dag_dict_equal(source, dag):
  assert dag.task_dict.keys() == source.keys()
  for task_id, downstream_list in source.items():
    assert dag.has_task(task_id)
    task = dag.get_task(task_id)
    assert task.downstream_task_ids == set(downstream_list)