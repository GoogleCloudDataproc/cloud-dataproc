# Serving the trained classifier on Cloud ML Engine

## Finding saved models

The trainer exports saved models to the following directory:
```
$JOB_DIR/export/Servo/
```
where `$JOB_DIR` is the directory you passed as the `--job-dir` argument to the
trainer (as in the previous section).

Within the `Servo` directory, models are stored in models are stored in folders
named by the epoch time at which they were exported.

## Hosting on Cloud ML Engine

There are two concepts you should be familiar with when hosting your TensorFlow
models using Cloud ML Engine:

1. models, which correspond to a single TensorFlow graph

2. versions, which correspond to the results of training that graph

A single model can potentially have multiple versions, each of which
corresponds to a distinct prediction service. The classifier we have trained
will be a single version of a model.

To begin with, then, we must create a Cloud ML Engine model to hold our
classifier. Let us call our model `sparky`:
```
$ gcloud ml-engine models create "sparky"
```

Now let us upload our latest export of the trained model as version `alpha` of
the `sparky` model. Assuming that
`MODEL_EXPORT=$JOB_DIR/export/Servo/<most recent timestamp>` be the location of
the saved model, you can create version `alpha` from your command line by:
```
$ gcloud ml-engine versions create "alpha" --model=sparky --origin=$MODEL_EXPORT
```

## Making predictions

In order to make predictions using this hosted model, we have to apply the same
preprocessing to the input data that we applied when we trained the model. In
this version of the guide, we explicitly only show how to do this in the case of
batch predictions. In the next version of the guide, we will show how this can
be done for online predictions using structured streaming in Spark.

As a stopgap, one could also use the model artifacts exported by the Spark
training job (the CSV file of categorical value counts stored on the path
specified by the `-x` argument to the Spark job) to manually preprocess a data
stream and perform [online prediction using Cloud Machine Learning
Engine](https://cloud.google.com/ml-engine/docs/concepts/prediction-overview#online_prediction_versus_batch_prediction).

### Batch prediction

Begin by preprocessing your data in `prediction` mode following the instructions
in the [Preprocessing](#preprocessing) section so that the preprocessed data
meant for prediction is stored in `$OUTPUT_DIR`. If you used Dataproc to
preprocess the data for prediction, `$OUTPUT_DIR` is a Cloud Storage bucket. If
not, then you will have to move your data to Cloud Storage to make it available
for batch prediction. You can do so using the [gsutil
tool](https://cloud.google.com/storage/docs/gsutil).

Once your data is on GCS, please set the `GCS_PATH` environment variable to the
reflect the path to the Cloud Storage directory containing the data meant for
preprocessing (with NO trailing `/`). We will store the predictions in the
`$GCS_PATH/predictions` directory.

Set the `PREDICTION_SERVICE_REGION` environment variable to the GCP region in
which your prediction service is running (most likely
`PREDICTION_SERVICE_REGION="us-central1"`).

To queue up the batch prediction job:
```
$ gcloud ml-engine jobs submit prediction sparky_alpha_1 \
--model=sparky --version=alpha \
--data-format=TF_RECORD \
--input-paths="$GCS_PATH/part-*" \
--output-path="$GCS_PATH/predictions" \
--region="$PREDICTION_SERVICE_REGION"
```

The job is completed asynchronously, so if you would like to monitor its status,
you can either view the logs on the Google Cloud Platform web dashboard or you
can use the following command at your command line:
```
$ gcloud ml-engine jobs stream-logs sparky_alpha_1
```

Alternatively, you can check up on the status of the job using
```
$ gcloud ml-engine jobs describe sparky_alpha_1
```

Once the job has completed the output will be written to the
`$GCS_PATH/predictions` directory in parts, with each line of each part
containing a distinct JSON object with two keys:

1. `classes` - 0 and 1, the two classes that our linear classifier chooses
   between, presented as the array `["0", "1"]`

2. `scores` - an array representing a probability vector, with the entry in
   index `i` representing the probability that the corresponding input belonged
   to class `i`.

- - -

[Home](../README.md)
