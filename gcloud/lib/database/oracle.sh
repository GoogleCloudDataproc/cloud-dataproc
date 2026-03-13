#!/bin/bash
#
# Oracle DB on GCE VM functions

function create_oracle_vm() {
  local phase_name="create_oracle_vm"
    print_status "Checking Oracle VM ${ORACLE_VM_NAME}..."
    report_result "Exists"
    return 0
  fi

  print_status "Creating Oracle VM ${ORACLE_VM_NAME}..."
  local log_file="create_oracle_vm_${ORACLE_VM_NAME}.log"

  local ova_url="https://yum.oracle.com/templates/OracleLinux/OL10/u0/x86_64/OL10U0_x86_64-olvm-b266.ova"
  local ova_file="OL10U0_x86_64-olvm-b266.ova"
  local machine_image_name="oracle-linux-10u0"
  local os_type="oraclelinux-10"
  local gcs_uri="gs://${BUCKET}/${ova_file}"
  local startup_script="${REPRO_TMPDIR}/oracle_startup.sh"

  # Create startup script content
  cat << 'EOF' > "${startup_script}"
#!/bin/bash
# oracle_startup.sh
echo "Starting Oracle DB setup..."

# !!! IMPORTANT: These commands are placeholders. You need to add the actual
# Oracle Database installation steps here for your specific version. !!!

# 1. Add Oracle Yum Repos if needed
# Example for 19c:
# sudo yum install -y oracle-database-preinstall-19c

# 2. Download Oracle Database Software (e.g., from Oracle website or GCS)
# Example: wget ... or gsutil cp ...

# 3. Unzip and Run Oracle Installer
# Example: unzip ...
# Example: ./runInstaller -silent -responseFile ...

# 4. Configure Listener
# Example: Using netca

# 5. Create Database
# Example: Using dbca

# 6. Open Firewall Port
sudo firewall-cmd --zone=public --add-port=1521/tcp --permanent
sudo firewall-cmd --reload

echo "Oracle DB setup script finished."
EOF

  print_status "  Downloading OVA..."
  if wget -O "${REPRO_TMPDIR}/${ova_file}" "${ova_url}" > "${REPRO_TMPDIR}/wget_${ova_file}.log" 2>&1; then
    report_result "Pass"
  else
    report_result "Fail"
    return 1
  fi

  print_status "  Uploading OVA to GCS..."
  if run_gcloud "${log_file}" gsutil cp "${REPRO_TMPDIR}/${ova_file}" "${gcs_uri}"; then
    report_result "Pass"
  else
    report_result "Fail"
    return 1
  fi

  print_status "  Importing Machine Image ${machine_image_name}..."
  if run_gcloud "${log_file}" gcloud compute machine-images import "${machine_image_name}" \
    --project="${PROJECT_ID}" \
    --source-uri="${gcs_uri}" \
    --os="${os_type}" \
    --zone="${ZONE}"; then
    report_result "Imported"
  else
    # Continue if image already exists
    if gcloud compute machine-images describe "${machine_image_name}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
      report_result "Exists"
    else
      report_result "Fail"
      return 1
    fi
  fi

  print_status "  Creating VM instance ${ORACLE_VM_NAME}..."
  if run_gcloud "${log_file}" gcloud compute instances create "${ORACLE_VM_NAME}" \
    --project="${PROJECT_ID}" \
    --zone="${ZONE}" \
    --source-machine-image="${machine_image_name}" \
    --metadata-from-file=startup-script="${startup_script}" \
    --scopes=cloud-platform; then
    report_result "Created"
  else
    report_result "Fail"
    return 1
  fi

  print_status "  Cleaning up local OVA file..."
  rm "${REPRO_TMPDIR}/${ova_file}"
  report_result "Done"
}
export -f create_oracle_vm

function delete_oracle_vm() {
  local phase_name="create_oracle_vm"
  print_status "Deleting Oracle VM ${ORACLE_VM_NAME}..."
  local log_file="delete_oracle_vm_${ORACLE_VM_NAME}.log"

  if gcloud compute instances describe "${ORACLE_VM_NAME}" --zone "${ZONE}" --project "${PROJECT_ID}" > /dev/null 2>&1; then
    if run_gcloud "${log_file}" gcloud compute instances delete "${ORACLE_VM_NAME}" \
      --project="${PROJECT_ID}" \
      --zone="${ZONE}" \
      --quiet; then
      report_result "Deleted"
    else
      report_result "Fail"
      return 1
    fi
  else
    report_result "Not Found"
  fi
}
export -f delete_oracle_vm
