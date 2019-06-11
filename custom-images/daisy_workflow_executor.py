# Copyright 2019 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#            http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Daisy workflow executor.
"""

import os
import subprocess
import tempfile


def run(daisy_path, workflow_script):
  """Runs a Daisy workflow."""

  if not os.path.isfile(daisy_path):
    raise RuntimeError("Invalid path to Daisy binary: '%s' is not a file.",
                       daisy_path)

  # Write workflow to file.
  temp_file = tempfile.NamedTemporaryFile(delete=False)
  try:
    temp_file.write(workflow_script.encode("utf-8"))
    temp_file.flush()
    temp_file.close()  # close this file but do not delete

    # Run Daisy workflow from the temp file, then wait for it to complete.
    pipe = subprocess.Popen([daisy_path, temp_file.name])
    pipe.wait()
    if pipe.returncode != 0:
      raise RuntimeError("Error building custom image.")
  finally:
    try:
      os.remove(temp_file.name)
    except OSError:
      pass
