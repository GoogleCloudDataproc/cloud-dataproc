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

import unittest
import daisy_workflow_generator


class TestDaisyWorkflowGenerator(unittest.TestCase):

  def test_generate_daisy_workflow(self):
    args = {
        'family' : 'debian9',
        'image_name' : 'my-image',
        'sources' : '"run.sh": "/tmp/run.sh", "init_actions.sh": "/tmp/my-script.sh"',
        'machine_type' : 'n1-standard-2',
        'disk_size' : 40,
        'gcs_bucket' : 'gs://my-bucket',
        'network' : 'my-network',
        'zone' : 'us-west1-a',
        'dataproc_base_image' : 'projects/cloud-dataproc/global/images/dataproc-1-4-deb9-20190510-000000-rc01',
        'service_account' : 'my-service-account',
        'oauth' : '',
        'subnetwork' : 'my-subnet',
        'project_id' : 'my-project',
        'shutdown_timer_in_sec': 500
    }

    workflow_script = daisy_workflow_generator.generate(args)

    expected_workflow_script = """\
    {
        "Name": "my-image",
        "Project": "my-project",
        "Sources": {
            "run.sh": "/tmp/run.sh", "init_actions.sh": "/tmp/my-script.sh"
        },
        "Zone": "us-west1-a",
        "GCSPath": "gs://my-bucket",
        "Steps": {
            "create-disks": {
                "CreateDisks": [
                    {
                        "Name": "my-image-install",
                        "SourceImage": "projects/cloud-dataproc/global/images/dataproc-1-4-deb9-20190510-000000-rc01",
                        "Type": "pd-ssd",
                        "SizeGb": "40"
                    }
                ]
            },
            "create-inst-install": {
                "CreateInstances": [
                    {
                        "Name": "my-image-install",
                        "Disks": [{"Source": "my-image-install"}],
                        "MachineType": "n1-standard-2",
                        "NetworkInterfaces": [{"network": "my-network", "subnetwork": "my-subnet"}],
                        "ServiceAccounts": [{"Email": "my-service-account", "Scopes": ["https://www.googleapis.com/auth/cloud-platform"]}],
                        "StartupScript": "run.sh",
                        "Metadata": {"shutdown-timer-in-sec" : "500"}
                    }
                ]
            },
            "wait-for-inst-install": {
                "TimeOut": "2h",
                "waitForInstancesSignal": [
                    {
                        "Name": "my-image-install",
                        "SerialOutput": {
                          "Port": 1,
                          "FailureMatch": "BuildFailed:",
                          "SuccessMatch": "BuildSucceeded:"
                        }
                    }
                ]
            },
            "wait-for-inst-shutdown": {
                "TimeOut": "2h",
                "waitForInstancesSignal": [
                    {
                        "Name": "my-image-install",
                        "Stopped": true
                    }
                ]
            },
            "create-image": {
                "CreateImages": [
                    {
                        "Name": "my-image",
                        "SourceDisk": "my-image-install",
                        "NoCleanup": true,
                        "ExactName": true,
                        "Family": "debian9"
                    }
                ]
            },
            "delete-inst-install": {
                "DeleteResources": {
                    "Instances": ["my-image-install"]
                }
            }
        },
        "Dependencies": {
            "create-inst-install": ["create-disks"],
            "wait-for-inst-install": ["create-inst-install"],
            "wait-for-inst-shutdown": ["wait-for-inst-install"],
            "create-image": ["wait-for-inst-shutdown"],
            "delete-inst-install": ["create-image"]
        }
    }\
    """
    formatted_workflow_script = ' '.join(workflow_script.split())
    formatted_expected_workflow_script = ' '.join(expected_workflow_script.split())
    self.assertEqual(formatted_workflow_script, formatted_expected_workflow_script)


if __name__ == '__main__':
    unittest.main()
