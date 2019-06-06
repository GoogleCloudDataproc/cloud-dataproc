import unittest

import workflow_generator


class TestWorkflowGenerator(unittest.TestCase):

  def test_generate_workflow_script(self):
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

    workflow_script = workflow_generator.generate_workflow_script(args)

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
