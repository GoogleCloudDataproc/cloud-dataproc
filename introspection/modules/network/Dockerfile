FROM python:3.9-slim

# Install gcloud
RUN apt-get update && apt-get install -y --no-install-recommends 
    curl 
    gnupg 
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list 
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - 
    && apt-get update && apt-get install -y google-cloud-sdk 
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy introspection framework and network module
COPY ../../inspect_env.py .
COPY . ./modules/network/

# Install Python dependencies for the network module
RUN pip install --no-cache-dir -r ./modules/network/requirements.txt

# Gcloud is authenticated by the Cloud Build service account
