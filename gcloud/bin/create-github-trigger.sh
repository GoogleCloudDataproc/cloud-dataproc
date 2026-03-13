#!/bin/bash

source lib/env.sh

# --- Configuration ---
PROJECT_ID="${CI_PROJECT_ID}"
REPO_NAME="${CI_CSR_REPO_NAME}"
REPO_OWNER="${CI_REPO_OWNER}"
# BRANCH_NAME is not used for PR triggers with comment control
REGION="${CI_CSR_REGION}"
BYOSA_EMAIL="${CI_BYOSA_EMAIL}"

if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "your-ci-test-project-id" ]]; then
  echo "ERROR: CI_PROJECT_ID not set or is placeholder in env.json" >&2
  exit 1
fi
if [[ -z "$REPO_NAME" ]]; then
  echo "ERROR: CI_CSR_REPO_NAME not set in env.json" >&2
  exit 1
fi
if [[ -z "$REPO_OWNER" ]]; then
  echo "ERROR: CI_REPO_OWNER not set in env.json" >&2
  exit 1
fi
if [[ -z "$BYOSA_EMAIL" ]]; then
  echo "ERROR: CI_BYOSA_EMAIL not set in env.json" >&2
  exit 1
fi

gcloud beta builds triggers create github --project="$PROJECT_ID" \
  --name="${REPO_NAME}-pr-trigger" \
  --repo-name="$REPO_NAME" \
  --repo-owner="$REPO_OWNER" \
  --pull-request-pattern=".*" \
  --comment-control=COMMENTS_ENABLED \
  --build-config="gcloud/cloudbuild.yaml" \
  --region="$REGION" \
  --service-account="projects/${PROJECT_ID}/serviceAccounts/${BYOSA_EMAIL}"

echo "Trigger creation command for '/gcbrun' comments on PRs executed."
echo "Ensure the Google Cloud Build GitHub App has permissions to read PRs and comments."
