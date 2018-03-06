#!/bin/bash

# run.sh will be used by Daisy workflow to run custom initialization
# script when creating a custom image.
#
# Immediately after Daisy workflow creates an GCE instance, it will
# execute run.sh on the GCE instance that it just created:
# 1. Download user's custom init action script from daisy sourth path.
# 2. Run the custom init action script.
# 3. Check for init action script output, and print success or failure
#    message. This message will get picked up by Daisy workflow on the
#    client machine.
# 4. Shutdown GCE instance.

# get daisy-sources-path
DAISY_SOURCES_PATH=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/daisy-sources-path" -H "Metadata-Flavor: Google")

# copy down init actions script
gsutil cp "${DAISY_SOURCES_PATH}/init_actions.sh" ./init_actions.sh

# run init actions
bash ./init_actions.sh

# get return code
RET_CODE=$?

# print failure message if install fails
if [[ $RET_CODE -ne 0 ]]; then
  echo "BuildFailed: Dataproc Initialization Actions Failed. Please check your initialization script."
else
  echo "BuildSucceeded: Dataproc Initialization Actions Succeeded."
fi

sleep 20 # wait for stdout to flush

shutdown -h now
