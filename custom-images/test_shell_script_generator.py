import unittest
import shell_script_generator


class TestShellScriptGenerator(unittest.TestCase):
  def test_generate_shell_script(self):
    args = {
        'run_id': 'custom-image-my-image-20190611-160823',
        'family': 'debian9',
        'image_name': 'my-image',
        'customization_script': '/tmp/my-script.sh',
        'machine_type': 'n1-standard-2',
        'disk_size': 40,
        'gcs_bucket': 'gs://my-bucket',
        'network': 'my-network',
        'zone': 'us-west1-a',
        'dataproc_base_image':
        'projects/cloud-dataproc/global/images/dataproc-1-4-deb9-20190510-000000-rc01',
        'service_account': 'my-service-account',
        'oauth': '',
        'subnetwork': 'my-subnet',
        'project_id': 'my-project',
        'shutdown_timer_in_sec': 500
    }

    shell_commands = shell_script_generator.Generator().generate(args)
    print(shell_commands)

    expected_shell_commands = [
        '#!/usr/bin/env bash', 'set -euxo pipefail', '', '# Exit trap.',
        'function exit_handler() {', "  echo 'Cleaning up before exiting.'",
        "  echo 'Uploading local logs to GCS bucket.'",
        '  gsutil -m rsync -r /tmp/custom-image-my-image-20190611-160823/logs gs://my-bucket/custom-image-my-image-20190611-160823/logs/',
        "  echo 'Deleting VM instance if needed.'",
        '  gcloud compute instances describe my-image-install --project=my-project --zone=us-west1-a >/dev/null 2>&1 && gcloud compute instances delete my-image-install --project=my-project --zone=us-west1-a -q',
        "  echo 'Deleting disk if needed.'",
        '  gcloud compute disks describe my-image-install --project=my-project --zone=us-west1-a >/dev/null 2>&1 && gcloud compute disks delete my-image-install --project=my-project --zone=us-west1-a -q',
        '  sleep 5', '}', '', 'trap exit_handler EXIT', '',
        'function main() {', '  ', "  echo 'Uploading files to GCS bucket.'",
        '  gsutil cp /tmp/my-script.sh gs://my-bucket/custom-image-my-image-20190611-160823/sources/init_actions.sh',
        '  gsutil cp run.sh gs://my-bucket/custom-image-my-image-20190611-160823/sources/',
        '  ', "  echo 'Creating disk.'",
        '  gcloud compute disks create my-image-install --project=my-project --zone=us-west1-a --image=projects/cloud-dataproc/global/images/dataproc-1-4-deb9-20190510-000000-rc01 --type=pd-ssd --size=40GB',
        '  ', "  echo 'Creating VM instance to run customization script.'",
        '  gcloud compute instances create my-image-install --project=my-project  --zone=us-west1-a --machine-type=n1-standard-2 --disk=auto-delete=yes,boot=yes,mode=rw,name=my-image-install --scopes=cloud-platform --metadata=shutdown-timer-in-sec=500,daisy-sources-path=gs://my-bucket/custom-image-my-image-20190611-160823/sources,startup-script-url=gs://my-bucket/custom-image-my-image-20190611-160823/sources/run.sh --subnet=my-subnet',
        '  ', "  echo 'Waiting for VM instance to shutdown.'",
        '  gcloud compute instances tail-serial-port-output my-image-install --project=my-project  --zone=us-west1-a --port=1 2>&1 | tee /tmp/custom-image-my-image-20190611-160823/logs/startup-script.log || true',
        '  ', "  echo 'Creating custom image.'",
        '  gcloud compute images create my-image --project=my-project  --source-disk-zone=us-west1-a --source-disk=my-image-install --family=debian9',
        '}', '', '',
        'mkdir -p /tmp/custom-image-my-image-20190611-160823/logs',
        'main "$@" 2>&1 | tee /tmp/custom-image-my-image-20190611-160823/logs/workflow.log'
    ]
    self.assertEqual(shell_commands, expected_shell_commands)


if __name__ == '__main__':
  unittest.main()
