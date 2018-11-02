# Build custom Dataproc images

This page describes how to generate a custom Dataproc image.

## Requirements

1.  Python 2.7+.
2.  gcloud >= 181.0.0 (2017-11-30)
    *   gcloud beta components is required. Use `gcloud components install beta`
        or `sudo apt-get install google-cloud-sdk`.
3.  Daisy, from
    [GoogleCloudPlatform/compute-image-tools](https://github.com/GoogleCloudPlatform/compute-image-tools)
    *   Please make sure the daisy binary have execution permission: `chmod +x
        daisy`.
4.  A GCE project with billing, Google Cloud Dataproc API, Google Compute Engine
    API, and Google Cloud Storage APIs enabled.
5.  Use `gcloud config set project <your-project>` to specify which project to
    use to create and save your custom image.

## Generate custom image

To generate a custom image, run the following command:

```shell
python generate_custom_image.py \
    --image-name <new_custom_image_name>
    --dataproc-version <Dataproc version>
    --customization-script <custom script to install custom packages>
    --daisy-path <path to local daisy binary>
    --zone <zone to create instance to build custom image>
    --gcs-bucket <gcs bucket to write logs>
```

### Arguments

*   **--image-name**: The name for custom image.
*   **--dataproc-version**: The Dataproc version for this custom image to build
    on. Example: `1.2.13`. For a complete list of Dataproc image versions,
    please refer to Dataproc [release
    notes](https://cloud.google.com/dataproc/docs/release-notes). To understand
    Dataproc versioning, please refer to
    [documentation](https://cloud.google.com/dataproc/docs/concepts/versioning/overview).
    **This argument is mutually exclusive with --base-image-uri**.
*   **--base-image-uri**: The full image URI for the base Dataproc image. The
    customiziation script will be executed on top of this image instead of
    an out-of-the-box Dataproc image. This image must be a valid Dataproc
    image. **This argument is mutually exclusive with --dataproc-version.**
*   **--customization-script**: The script used to install custom packages on
    the image.
*   **--daisy-path**: The path to Daisy binary.
*   **--zone**: The GCE zone for running your GCE instance.
*   **--gcs-bucket**: A GCS bucket to store the logs of building custom image.

#### Optional Arguments

*   **--family**: The family of the source image. This will cause the latest
    non-deprecated image in the family to be used as the source image.
*   **--project-id**: The project Id of the project where the custom image is
    created and saved. The default project Id is the current project id
    specified in `gcloud config get-value project`.
*   **--oauth**: The OAuth credential file used to call Google Cloud APIs. The
    default OAuth is the application-default credentials from gcloud.
*   **--machine-type**: The machine type used to build custom image. The default
    is `n1-standard-1`.
*   **--no-smoke-test**: This parameter is used to disable smoke testing the
    newly built custom image. The smoke test is used to verify if the newly
    built custom image can create a functional Dataproc cluster. Disabling this
    step will speed up the custom image build process; however, it is not
    advised. Note: The smoke test will create a Dataproc cluster with the newly
    built image, runs a short job and deletes the cluster in the end.
*   **--network**: This parameter specifies the GCE network to be used to launch
    the GCE VM instance which builds the custom Dataproc image. The default
    network is 'global/networks/default'. If the default network does not exist
    in your project, please specify a valid network interface. For more
    information on network interfaces, please refer to (GCE VPC
    documentation)[https://cloud.google.com/vpc/docs/vpc].
*   **--subnetwork**: This parameter specifies the subnetwork that is used to
    launch the VM instance that builds the custom Dataprocimage. A full
    subnetwork URL is required. The default subnetwork is None. For more
    information, please refer to (GCE VPC
    documentation)[https://cloud.google.com/vpc/docs/vpc].
*   **--service-account**: The service account that is used to launch the VM
    instance that builds the custom Dataproc image. The scope of this service
    account is defaulted to "/auth/cloud-platform", which authorizes VM instance
    the access to all cloud platform services that is granted by IAM roles.
    Note: IAM role must allow the VM instance to access GCS bucket in order to
    access scripts and write logs.
*   **--extra-sources**: Additional files/directories uploaded along with
    customization script. This argument is evaluated to a json dictionary.
    Read more about
    (sources in daisy)[https://googlecloudplatform.github.io/compute-image-tools/daisy-workflow-config-spec.html#sources] 
*   **--disk-size**: The size in GB of the disk attached to the VM instance
    used to build custom image. The default is `15` GB.
*   **--base-image-uri**: The partial image URI for the base Dataproc image. The
    customization script will be executed on top of this image instead of an
    out-of-the-box Dataproc image. This image must be a valid Dataproc image.
    The format of the partial image URI is the following:
    "projects/<project_id>/global/images/<image_name>".
*   **--exipre-day**: The day of the custom image will expire. 
    The default is `30` Days.

### Example

Create a custom image with name `custom-image-1-2-3` with Dataproc version
`1.12.11`:
```shell
python generate_custom_image.py \ --image-name
custom-image-1-2-3 --dataproc-version 1.2.11 --customization-script
~/custom-script.sh --daisy-path ~/daisy --zone us-central1-f --gcs-bucket
gs://my-test-bucket
```

Create a custom image with name `custom_image` and disables smoke test:
```shell
python generate_custom_image.py \ --image-name custom-image-1-2-3
--dataproc-version 1.2.11 --customization-script ~/custom-script.sh --daisy-path
~/daisy --zone us-central1-f --gcs-bucket gs://my-test-bucket --no-smoke-test
```

Create a custom image with name `custom_image` and upload extra sources to the image:
```shell
python generate_custom_image.py \ --image-name custom-image-1-2-3
--dataproc-version 1.2.11 --customization-script ~/custom-script.sh --daisy-path
~/daisy --zone us-central1-f --gcs-bucket gs://my-test-bucket --extra-sources "{\"requirements.txt\": \"/path/to/requirements.txt\"}"
```
