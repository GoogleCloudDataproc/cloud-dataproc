Here are the instructions for running the Secure Web Proxy (SWP) CUJ.

-----

### 1\. Configure Your Environment

First, you'll need to set up your `env.json` file with your project details and the name for your new SWP instance.

```bash
# Navigate to the gcloud directory
cd gcloud/

# Copy the sample configuration
cp env.json.sample env.json

# Open env.json in your favorite editor and set the following keys:
# - PROJECT_ID
# - REGION
# - SWP_INSTANCE_NAME (e.g., "my-swp-instance")
vi env.json
```

-----

### 2\. Run the Onboarding Script

Next, you'll run the onboarding script to provision the SWP instance and its related resources. This is a one-time setup that may take a few minutes to complete.

```bash
# From the gcloud/ directory, run the onboarding script
bash onboarding/create_swp_instance.sh
```

-----

### 3\. Run the CUJ

Now you're ready to run the CUJ itself. This will create a Dataproc cluster in a private network and configure it to use the SWP instance for all its outbound internet traffic.

```bash
# Navigate to the CUJ directory
cd cuj/gce/secure-web-proxy/

# Create the Dataproc cluster and its related resources
bash manage.sh up

# When you're finished, you can tear down the cluster and its resources
bash manage.sh down
```

-----

### 4\. Cleanup

When you're completely finished with your testing, you can run the teardown script to remove the SWP instance and its related resources.

```bash
# From the gcloud/ directory, run the teardown script
bash onboarding/delete_swp_instance.sh
```
