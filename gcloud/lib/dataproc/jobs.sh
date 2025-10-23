#!/bin/bash
#
# Dataproc Job/Debug functions

function get_yarn_applications() {
  echo "not yet implemented"
}
export -f get_yarn_applications

function get_jobs_list() {
  if [[ -z ${JOBS_LIST} ]]; then
    JOBS_LIST="$(gcloud dataproc jobs list --region ${REGION} --format json)"
  fi
  echo "${JOBS_LIST}"
}
export -f get_jobs_list

function diagnose () {
  local bdoss_path=${HOME}/src/bigdataoss-internal
  if [[ ! -d ${bdoss_path}/drproc ]]; then
    echo "mkdir -p ${bdoss_path} ; pushd ${bdoss_path} ; git clone sso://bigdataoss-internal/drproc ; popd"
    exit -1
  fi
  print_status "Running cluster diagnose for ${CLUSTER_NAME}..."
  local log_file="diagnose_${CLUSTER_NAME}.log"
  DIAGNOSE_CMD="gcloud dataproc clusters diagnose ${CLUSTER_NAME} --region ${REGION}"
  if run_gcloud "${log_file}" ${DIAGNOSE_CMD}; then
    report_result "Pass"
    DIAG_URL=$(cat "${REPRO_TMPDIR}/${log_file}" | perl -ne 'print if m{^gs://.*/diagnostic.tar.gz\s*$}')
    if [[ -n "${DIAG_URL}" ]]; then
      print_status "  Downloading ${DIAG_URL}..."
      if run_gcloud "download_diagnose.log" gsutil cp -q "${DIAG_URL}" "${REPRO_TMPDIR}/"; then
         report_result "Pass"
         local diag_file="${REPRO_TMPDIR}/$(basename ${DIAG_URL})"
         print_status "  Running drproc on ${diag_file}..."
         if [[ ! -f venv/${CLUSTER_NAME}/pyvenv.cfg ]]; then
            mkdir -p venv/
            python3 -m venv venv/${CLUSTER_NAME}
            source venv/${CLUSTER_NAME}/bin/activate
            python3 -m pip install -r ${bdoss_path}/drproc/requirements.txt
          else
            source venv/${CLUSTER_NAME}/bin/activate
          fi
          python3 ${bdoss_path}/drproc/drproc.py "${diag_file}"
          report_result "Done"
      else
         report_result "Fail"
      fi
    fi
  else
    report_result "Fail"
  fi
}
export -f diagnose