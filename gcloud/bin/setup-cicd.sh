#!/bin/bash

# One-time setup script for CI/CD environment using Cloud Build

set -e
set -u

export TIMESTAMP="${TIMESTAMP:-$(date +%s)}"
source lib/env.sh # Sources variables from env.json

# --- Configuration ---
CI_PROJECT_ID="${CI_PROJECT_ID}"
CI_GCP_CREDENTIALS_PATH="${CI_GCP_CREDENTIALS_PATH}"
CI_CSR_REPO_NAME="${CI_CSR_REPO_NAME}"
CI_CSR_REGION="${CI_CSR_REGION}"
CI_GITHUB_CONNECTION_NAME="${CI_GITHUB_CONNECTION_NAME}"
CI_TRIGGER_BRANCH="${CI_TRIGGER_BRANCH}"

if [[ "$CI_PROJECT_ID" == "your-ci-test-project-id" || -z "$CI_PROJECT_ID" ]]; then
  echo "ERROR: Please update CI_PROJECT_ID in env.json"
  exit 1
fi
if [[ "$CI_GCP_CREDENTIALS_PATH" == "/path/to/your/ci-service-account.json" || ! -f "$CI_GCP_CREDENTIALS_PATH" ]]; then
  echo "ERROR: Please update CI_GCP_CREDENTIALS_PATH in env.json and ensure the file exists."
  exit 1
fi
if [[ -z "$CI_CSR_REPO_NAME" ]]; then
  echo "ERROR: Please update CI_CSR_REPO_NAME in env.json."
  exit 1
fi

echo "Setting up CI/CD for project: $CI_PROJECT_ID"
gcloud config set project "$CI_PROJECT_ID"

# --- Enable Services ---
echo "Enabling necessary services in $CI_PROJECT_ID..."
gcloud services enable \
  secretmanager.googleapis.com \
  cloudbuild.googleapis.com \
  containerregistry.googleapis.com \
  compute.googleapis.com \
  dataproc.googleapis.com \
  container.googleapis.com \
  networksecurity.googleapis.com \
  networkservices.googleapis.com \
  privateca.googleapis.com \
  certificatemanager.googleapis.com \
  sourcerepo.googleapis.com \
  --project="$CI_PROJECT_ID"

# --- Create Secrets ---
echo "Creating secrets in $CI_PROJECT_ID..."

# Use the main env.json for the test environment secret
gcloud secrets create test-env-json --replication-policy=automatic --project="$CI_PROJECT_ID" --quiet || echo "Secret test-env-json already exists."
gcloud secrets versions add test-env-json --data-file="env.json" --project="$CI_PROJECT_ID"

gcloud secrets create gcp-credentials --replication-policy=automatic --project="$CI_PROJECT_ID" --quiet || echo "Secret gcp-credentials already exists."
gcloud secrets versions add gcp-credentials --data-file="$CI_GCP_CREDENTIALS_PATH" --project="$CI_PROJECT_ID"

echo "Secrets created."

# --- Create BYOSA Service Account ---
BYOSA_EMAIL="${CI_BYOSA_EMAIL}"
BYOSA_NAME=$(echo "$BYOSA_EMAIL" | cut -d @ -f 1)
echo "Checking for BYOSA: $BYOSA_EMAIL"
if ! gcloud iam service-accounts describe "$BYOSA_EMAIL" --project="$CI_PROJECT_ID" > /dev/null 2>&1; then
  echo "Creating BYOSA: $BYOSA_EMAIL..."
  gcloud iam service-accounts create "$BYOSA_NAME" \
    --description="Service Account for Cloud Build CI/CD" \
    --display-name="Dataproc Repro CICD" \
    --project="$CI_PROJECT_ID"
else
  echo "BYOSA $BYOSA_EMAIL already exists."
fi

# Grant Owner role to BYOSA (SCOPE DOWN FOR PRODUCTION)
echo "WARNING: Granting roles/owner to the BYOSA $BYOSA_EMAIL in $CI_PROJECT_ID."
gcloud projects add-iam-policy-binding "$CI_PROJECT_ID" \
  --member="serviceAccount:$BYOSA_EMAIL" \
  --role='roles/owner'

# --- Grant Permissions to Cloud Build SA ---
PROJECT_NUMBER=$(gcloud projects describe "$CI_PROJECT_ID" --format="value(projectNumber)")
CLOUD_BUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

echo "Granting permissions to Cloud Build service account: $CLOUD_BUILD_SA"

# Grant access to secrets
gcloud secrets add-iam-policy-binding test-env-json \
  --member="serviceAccount:${CLOUD_BUILD_SA}" \
  --role='roles/secretmanager.secretAccessor' \
  --project="$CI_PROJECT_ID"
gcloud secrets add-iam-policy-binding gcp-credentials \
  --member="serviceAccount:${CLOUD_BUILD_SA}" \
  --role='roles/secretmanager.secretAccessor' \
  --project="$CI_PROJECT_ID"

echo "WARNING: Granting roles/owner to the Cloud Build SA in $CI_PROJECT_ID. Scope down for production."
gcloud projects add-iam-policy-binding "$CI_PROJECT_ID" \
  --member="serviceAccount:${CLOUD_BUILD_SA}" \
  --role='roles/owner'

# Grant Cloud Build SA permission to ACT AS the BYOSA
echo "Granting Service Account User role to $CLOUD_BUILD_SA on $BYOSA_EMAIL..."
gcloud iam service-accounts add-iam-policy-binding "$BYOSA_EMAIL" \
  --member="serviceAccount:${CLOUD_BUILD_SA}" \
  --role='roles/iam.serviceAccountUser' \
  --project="$CI_PROJECT_ID"

echo "Permissions granted."

# --- Write cloudbuild.yaml ---
CLOUDBUILD_FILE="cloudbuild.yaml"
echo "Writing $CLOUDBUILD_FILE..."
cat > "$CLOUDBUILD_FILE" << EOF
steps:
  - name: 'gcr.io/cloud-builders/gcloud'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        echo "\$TEST_ENV_JSON" > env.json
        echo "CI/CD env.json content:"
        cat env.json
  # --- Test Standard DPGCE ---
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'Test Standard Create'
    entrypoint: 'bash'
    args: ['-c', 'source lib/env.sh && ./bin/create-dpgce && ./bin/audit-dpgce-create']
    env:
      - 'PROJECT_ID=\$PROJECT_ID'
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'Test Standard Destroy'
    entrypoint: 'bash'
    args: ['-c', 'source lib/env.sh && ./bin/destroy-dpgce --force && ./bin/audit-dpgce-destroy --force']
    env:
      - 'PROJECT_ID=\$PROJECT_ID'
    waitFor: ['Test Standard Create']

  # --- Test Private DPGCE ---
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'Test Private Create'
    entrypoint: 'bash'
    args: ['-c', 'source lib/env.sh && ./bin/create-dpgce-private && ./bin/audit-private-create']
    env:
      - 'PROJECT_ID=\$PROJECT_ID'
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'Test Private Destroy'
    entrypoint: 'bash'
    args: ['-c', 'source lib/env.sh && ./bin/destroy-dpgce-private --force && ./bin/audit-private-destroy --force']
    env:
      - 'PROJECT_ID=\$PROJECT_ID'
    waitFor: ['Test Private Create']

  # --- Test Custom Standard DPGCE ---
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'Test Custom Std Create'
    entrypoint: 'bash'
    args: ['-c', 'source lib/env.sh && ./bin/create-dpgce-custom && ./bin/audit-dpgce-create-custom']
    env:
      - 'PROJECT_ID=\$PROJECT_ID'
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'Test Custom Std Destroy'
    entrypoint: 'bash'
    args: ['-c', 'source lib/env.sh && ./bin/destroy-dpgce --force && ./bin/audit-dpgce-destroy --force']
    env:
      - 'PROJECT_ID=\$PROJECT_ID'
    waitFor: ['Test Custom Std Create']

  # --- Test Custom Private DPGCE ---
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'Test Custom Pvt Create'
    entrypoint: 'bash'
    args: ['-c', 'source lib/env.sh && ./bin/create-dpgce-custom-private && ./bin/audit-dpgce-create-custom-private']
    env:
      - 'PROJECT_ID=\$PROJECT_ID'
  - name: 'gcr.io/cloud-builders/gcloud'
    id: 'Test Custom Pvt Destroy'
    entrypoint: 'bash'
    args: ['-c', 'source lib/env.sh && ./bin/destroy-dpgce-private --force && ./bin/audit-private-destroy --force']
    env:
      - 'PROJECT_ID=\$PROJECT_ID'
    waitFor: ['Test Custom Pvt Create']

availableSecrets:
  secretManager:
  - versionName: projects/\$PROJECT_ID/secrets/test-env-json/versions/latest
    env: 'TEST_ENV_JSON'

options:
  env:
  - 'PROJECT_ID=$CI_PROJECT_ID' # Use CI_PROJECT_ID here
  - 'CLOUDSDK_CORE_DISABLE_PROMPTS=1'
substitutions:
  _CI_PROJECT_ID: "$CI_PROJECT_ID"
timeout: 3600s # 60 minutes
EOF
echo "$CLOUDBUILD_FILE written."

# --- Configure Triggers ---
echo "Instructions to create Cloud Build Trigger:"
echo "1. Go to Cloud Build Triggers in project $CI_PROJECT_ID."
echo "2. Connect your repository if not already done."
echo "3. Create a trigger:"
echo "   - Name: ${CI_CSR_REPO_NAME}-trigger"
echo "   - Event: Push to a branch"
echo "   - Source: Your repository, Branch: ^${CI_TRIGGER_BRANCH}$"
echo "   - Configuration: Cloud Build configuration file (yaml)"
echo "   - Location: /cloudbuild.yaml"
echo "   - Service Account: Default Cloud Build SA should be fine with above permissions."

echo "Alternative gcloud command to create trigger (adjust connection details if not using CSR):"
echo "gcloud beta builds triggers create github --project="$CI_PROJECT_ID" "
echo "  --name="${CI_CSR_REPO_NAME}-trigger" "
echo "  --repo-name="${CI_CSR_REPO_NAME}" "
echo "  --repo-owner="YOUR_GITHUB_USERNAME" "
echo "  --branch-pattern="^${CI_TRIGGER_BRANCH}$" "
echo "  --build-config="cloudbuild.yaml" "
echo "  --region="$CI_CSR_REGION""

echo "Setup script finished. PLEASE REVIEW AND ADJUST env.json and the trigger commands."
