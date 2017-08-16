gcloud ml-engine jobs submit training $JOB --stream-logs --runtime-version 1.2 \
  --job-dir "gs://cloudml-spark-tf-connector/ml-engine/$JOB" \
  --module-name trainer.task --package-path trainer --region "us-central1" \
  --config config-standard.yaml -- \
  --train-glob "gs://cloudml-spark-tf-connector/criteo/med-test-data/alpha/train/part-*" \
  --eval-glob "gs://cloudml-spark-tf-connector/criteo/med-test-data/alpha/eval/part-*" \
  --batch-size 1000 --train-steps 1
