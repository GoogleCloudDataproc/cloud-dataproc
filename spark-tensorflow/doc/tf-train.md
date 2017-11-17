# Training the linear classifier

Once you have preprocessed your training data in training mode and some
evaluation data in evaluation mode, you can use it to train the
TensorFlow classifier. For this, whether your run your training
job locally or on Google Cloud Platform, you will be using [this
code](../trainer/task.py).

## Preprocess your artifacts

The artifact files as written by Spark need one more preprocessing step before 
they are ready for consumption by the Tensorflow graph. Specifically, they
need to be renamed and the count of the categorical feature value files must
be created.

This preprocessing can be done on either a local directory with the `preprocess_artifacts_local.py` command:

```
  $ python preprocess_artifacts_local.py <your local artifact directory>
``` 

or on a GCS bucket with the `preprocess_artifacts_gcs.py` command:

```
  $ python preprocess_artifacts_gcs.py <your GCS artifacts>
```  

## Command line arguments

Regardless of how you run the training job, you will *have* to pass it the
following arguments:

1. `--job-dir`: Location where TensorFlow should store the model exported by
   the training job.

2. `--train-dir`: Directory containing training data.
3. `--eval-dir`: Directory containing evaluation data.

Let us assume that the values for each of these arguments are stored under
`$JOB_DIR, $TRAIN_DIR, $EVAL_DIR` respectively.

You may also *optionally* pass the following arguments:

1. `--batch-size`: This is the prescribed size of each training batch.

2. `--train-steps`: This is the number of steps of training that should be
   performed. If you do not specify this parameter, the model will train itself
   continually.

## Training locally

Begin by setting up your environment with:
```
$ pip install -r requirements.txt
```

(It is highly recommended that you do this in a fresh Python 2 virtual
environment.)

With your environment set up, you can run the training job by:
```
$ python task.py --job-dir $JOB_DIR --train-dir $TRAIN_DIR --eval-dir $EVAL_DIR
```

If you want to monitor how your model is faring against your evaluation data,
you can run:
```
$ tensorboard --logdir=$JOB_DIR
```
and go to `http://localhost:6006` in your browser.

## Training in the cloud

Make sure that you have enabled MLEngine. Decide upon a name for your training
job, and store it under the `JOB` environment variable. Then:
```
gcloud ml-engine jobs submit training $JOB --stream-logs --runtime-version 1.2 \
  --job-dir $JOB_DIR \
  --module-name trainer.task --package-path trainer --region "us-central1" \
  -- --train-dir $TRAIN_DIR --eval-dir $EVAL_DIR --artifact-dir $ARTIFACT_DIR
```

(Note, the extra `--` on the last line of the command above is not a typo. That
is the pattern used in the `gcloud` command to signify that all subsequent
arguments are not for `gcloud` itself but are rather parameters to the program
being executed by `gcloud`. In this case, `trainer.task`.)

If you are using a sizable portion of the Kaggle challenge data set, you may
want to run several batches in parallel to speed up training. To do so, you can
specify MLEngine configuration as outlined
[here](https://cloud.google.com/ml-engine/docs/concepts/training-overview). The
TL;DR version is that you should make a YAML file representing a
[TrainingInput](https://cloud.google.com/ml-engine/reference/rest/v1/projects.jobs#traininginput)
argument to the MLEngine API and pass this YAML file to `gcloud ml-engine jobs
submit training` under the `--config` argument.

This project provides a [sample YAML file](./config-standard.yaml) which can
be passed in the training command as follows:
```
gcloud ml-engine jobs submit training $JOB --stream-logs --runtime-version 1.2 \
  --job-dir $JOB_DIR \
  --module-name trainer.task --package-path trainer --region "us-central1" \
  --config config-standard.yaml \
  -- --train-dir $TRAIN_DIR --eval-dir $EVAL_DIR
```

- - -

[Home](../README.md)
