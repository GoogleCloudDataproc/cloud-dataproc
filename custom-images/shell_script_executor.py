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
Shell script executor.
"""

import os
import subprocess
import sys
import tempfile


def run(shell_script):
  """Runs a Shell script."""

  # Write the script to a temp file.
  temp_file = tempfile.NamedTemporaryFile(delete=False)
  try:
    temp_file.write(shell_script.encode("utf-8"))
    temp_file.flush()
    temp_file.close()  # close this file but do not delete

    # Run the shell script from the temp file, then wait for it to complete.
    pipe = subprocess.Popen(
        ['/usr/bin/bash', temp_file.name],
        stdout=sys.stdout,
        stderr=sys.stderr
    )
    #for line in iter(pipe.stdout.readline, b''):
    #  if not line:
    #    print(line)
    #pipe.stdout.close()
    pipe.wait()
    if pipe.returncode != 0:
      raise RuntimeError("Error building custom image.")
  finally:
    try:
      os.remove(temp_file.name)
    except OSError:
      pass
