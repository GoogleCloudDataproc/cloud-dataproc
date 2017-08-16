# Using Spark to feed TensorFlow

This example shows you how to use [Apache Spark](https://spark.apache.org/) to prepare data for (batched) consumption by a [TensorFlow Estimator](https://www.tensorflow.org/api_docs/python/tf/estimator/Estimator).

Please do dive into the code provided in this example. We have attempted to
break it down into segments that you could use, with very minor tweaks, in your own
applications.

If you experience any difficulty running this example, please reach out directly
on GitHub to one of the maintainers listed in [MAINTAINERS.md](./MAINTAINERS.md).

If you would like to contribute, please fork this repository and
create a pull request with your contribution with one of the
[maintainers](./MAINTAINERS.md) as a reviewer.

- - -

##Prerequisites

1. You are familiar with [Python](https://www.python.org/).

2. You have [TensorFlow set up](https://www.tensorflow.org/install/). We will use the [Python API](https://www.tensorflow.org/api_docs/python/) to communicate with it.

3. You have [Spark set up](https://spark.apache.org/docs/latest/) and
   you know [the basics](https://spark.apache.org/docs/latest/quick-start.html).

4. You are familiar with [scala](http://scala-lang.org/) and have [SBT](http://www.scala-sbt.org/) installed. We will use scala to communicate with Spark.

5. You have access to the [Criteo Kaggle data set](http://labs.criteo.com/2014/02/kaggle-display-advertising-challenge-dataset/). Unless you are interested in stress testing Cloud products, I highly recommend making it smaller.

6. The data should be available to your Spark cluster. If you intend to run this example on [Google Cloud Platform](https://cloud.google.com/), this means putting it in Google Cloud Storage:
       a. [Sign up for free tier](https://cloud.google.com/free/) if you haven't already.
       b. [Create a project](https://cloud.google.com/resource-manager/docs/creating-managing-projects).
       c. Store your data set(s) into a [Google Cloud Storage
       bucket](https://cloud.google.com/storage/) associated with your project.
       [TODO: Include instructions for how to do this.]

7. If you plan to do use [Dataproc](https://cloud.google.com/dataproc/docs/) for
   preprocessing or [Machine Learning
   Engine](https://cloud.google.com/ml-engine/docs/) for training/prediction,
   please [enable them in your
   project](https://support.google.com/cloud/answer/6158841?hl=en).

- - -

## Overview

At the moment, the best way to connect from Spark to TensorFlow is to use Spark
to produce [TFRecords
files](https://www.tensorflow.org/api_guides/python/python_io#tfrecords_format_details)
which contain the Spark-processed data serialized as [TensorFlow
Examples](https://www.tensorflow.org/api_docs/python/tf/train/Example). These
files can then be read into TensorFlow graphs using [standard TensorFlow input
constructs](https://www.tensorflow.org/programmers_guide/reading_data).

Although Spark does not provide an off-the-shelf technique to create TFRecords
files, the [tensorflow/ecosystem](https://github.com/tensorflow/ecosystem) has
implemented a [Spark-TensorFlow
connector](https://github.com/tensorflow/ecosystem/tree/master/spark/spark-tensorflow-connector).
This connector allows us to specify `"tfrecords"` as a parameter to the
[DataFrame](https://spark.apache.org/docs/latest/api/scala/index.html#org.apache.spark.sql.Dataset)'s
`write` method to generate TFRecords.

Our workflow is as follows:

1. We will use Spark to convert batches of data in Criteo tsv files into TFrecords.

2. We will use these TFRecords to train a [linear classifier implemented in
   TensorFlow](https://www.tensorflow.org/api_docs/python/tf/contrib/learn/LinearClassifier).

3. We will use the trained classifier to make predictions on batches of
   unclassified Criteo data.

- - -

## Understanding the data

The Criteo Kaggle data set contains both labelled (`train.txt`) and unlabelled (`test.txt`) data. Each of data points in this data set contains information about an advertisement and a user to whom that advertisement was displayed. Each line of the data files represents a single data point and consists (in order) of the following features, separated by tabs:

1. 13 integer features, which "mostly" represent counts as per the Criteo
   description of the data set on Kaggle.

2. 26 categorical features, each of whose values has been hashed so as to strip
   them of any inferrable semantic significance.

Additionally, the data points in the `train.txt` file are prepended by their
label - 1 if the advertisement corresponding to that data point was clicked on
by the user corresponding to that data point, and 0 otherwise.


### Mapping categories to numbers

[Source](./prepare/src/main/scala/com/google/cloud/ml/samples/criteo/CriteoPreprocessor.scala)

As we are planning to use a linear model to perform our classification, there is an
expectation from the model that every feature take on a numerical value. This means
that we need to adopt a policy for the conversion of the categorical feature
values into numbers. Moreover, as the relative sizes of the numbers representing
each cateogrical feature value will affect the linear classification of our data
points, we must make sure that the numerical scheme contains some information
about the categorical values they are encoding. We will apply the following two
constraints:

1. We will treat each categorical feature independently from the others. This
   means that we will have a distinct numerical embedding for the values of each
   categorical feature.

2. For a given categorical feature, for any two values, the relative sizes of
   their corresponding numerical values will reflect the relative frequencies
   with which the categorical values appear in the data set.

This suggests the following simple policy for our embeddings:
*We will assign each value of a given categorical feature its rank once the values for that feature have been sorted (in descending order) by frequency.*

This is good for the purposes of training. However, when we are trying to make
predictions, it would be possible for us to run into values that we didn't see
while we were training the model. In this case, we will simply assign a negative
integer of large absolute value to the categorical value in question. [TODO:
Implement this?]

### Handling missing values

[Source](./prepare/src/main/scala/com/google/cloud/ml/samples/criteo/CriteoPreprocessor.scala)

The next problem we need to address is that of missing values. In the
Criteo data set, there are no guarantees regarding any feature in any data
point. For any data point, any feature could have a missing value. Given the
constraints of our model in that it needs its inputs to have numerical features,
we need to also adopt a policy for how we assign numerical values to missing
features.

Note that it would be unwise for us to simply ignore data points with any
missing values -- the fact that a value is missing could itself contain signal
about how to classify the data point. Therefore we seek a policy which assigns
numerical values to even missing features.

For categorical features, there is a simple scheme at hand -- we will
treat empty values as their own category on the same footing as the other
categories. (If you look at the [code](./prepare/src/main/scala/com/google/cloud/ml/samples/criteo/CriteoPreprocessor.scala), you'll see that we are filling in such
feature values with the string `"-10"` as it achieves the same purpose while
keeping our code simple.)

For integer features, we see from some very simple queries over our data that
the smallest integer value that appears in the data is -3:

For integer features, some queries over our data show that,
although there are negative values, no integer less than -3 appears in the data
set. Let us proceed very simply by replacing missing integer values with the
integer `-10`.

- - -

##Preprocessing

Before we can preprocess the Criteo data, we must package our Spark script into
a JAR file, as well as the `spark-tensorflow-connector` and the
[scopt](https://github.com/scopt/scopt) library, which we use to parse arguments
to our Spark script. We will submit the JAR files for these three components to
our Spark cluster together in order to run preprocessing jobs.

### Packaging the Criteo preprocessor

This is as simple as going to the [preprocessor directory](./prepare) and
running:
`$ sbt clean package`

This will create a JAR file whose path (relative to the root directory for this
project) is `prepare/target/scala-2.11/criteo-prepare_2.11-1.0.jar`. Let us set
the variable
```
$ CRITEO_JAR=prepare/target/scala-2.11/criteo-prepare_2.11-1.0.jar
```

### spark-tensorflow-connector

You will have to provide Spark with the JAR file to this component as,
otherwise, it will not know how to write a DataFrame into `.tfrecords` files.

To build the `spark-tensorflow-connector` JAR, you can [follow the
instructions in the tensorflow/ecosystem
docs](https://github.com/tensorflow/ecosystem/tree/master/spark/spark-tensorflow-connector).
(Don't worry, this is painless.)

Let us set the variable
```
$ SPARK_TF_CONNECTOR_JAR=<path to spark-tensorflow-connector JAR you just built>
```

### scopt

We will use [scopt](https://github.com/scopt/scopta) to process arguments to our
Spark script. We will provide the package information to Spark when we run the
job.

### Submitting the preprocessing job

With all our preparation done, we can now submit the Spark job to preprocess our
Criteo data set. Let us assume that the input data is stored under the path
`$BASE_DIR/$CRITEO_DATASET` and that we want the `.tfrecords` files to be written to
`$BASE_DIR/$OUTPUT_DIR`.

Let us set `MODE=train`, `MODE=evaluate`, or `MODE=predict` depending on whether
the data set in question is intended for training, evaluation, or prediction.

Note: If you set `MODE=train`, then the preprocessor will construct embeddings
for each of the categorical features in the data set and store artifacts used to
load these embeddings into the `$MODEL` directory. For any other value of `$MODE`,
the preprocessor will expect to find these artifacts in the specified `$MODEL`
directory.

### Local preprocessing

```
$ spark-submit --master local --class \
com.google.cloud.ml.samples.criteo.CriteoPreprocessingApplication --packages com.github.scopt:scopt_2.11:3.6.0 --jars \
"$SPARK_TF_CONNECTOR_JAR" $CRITEO_JAR --base $BASE_DIR --in $CRITEO_DATASET --out $OUTPUT_DIR -m $MODE -x $MODEL $@
```

### Cloud preprocessing

Alternatively, you can use [Dataproc](https://cloud.google.com/dataproc/docs/) to
perform preprocessing in the cloud.

Begin by [creating a Dataproc
cluster](https://cloud.google.com/dataproc/docs/guides/create-cluster). Store
its name as `CLUSTER=<name of your Dataproc cluster>`.

Make sure that your data lives in a Google Cloud Storage bucket accessible to
your Dataproc cluster as described in the [Prerequisites](#prerequisites). Store
the bucket URL under the `BUCKET` variable, and let the `CRITEO_DATASET` and
`OUTPUT_DIR` variables be defined above relative to the GCS bucket URL.

Then:
```
$ gcloud dataproc jobs submit spark --cluster $CLUSTER --properties spark.jars.packages=com.github.scopt:scopt_2.11:3.6.0
--jars "$SPARK_TF_CONNECTOR_JAR,$CRITEO_JAR"
--class "com.google.cloud.ml.samples.criteo.CriteoPreprocessingApplication" --
-b $BUCKET -i $CRITEO_DATASET -o $OUTPUT_DIR -m $MODE -x $MODEL $@
```

### Preparing for training

However you choose to preprocess the Criteo data, you should earmark some of the
training data for evaluation purposes. For example, if you are working with the
entire Kaggle challenge data set, you can create your training data set with:

```
$ head -n 45000000 train.txt > train_subset.txt
```
and your evaluation data set with:
```
$ tail -n 840617 train.txt > eval_subset.txt
```

When you preprocess these data sets, make sure to store them under distinct
output directories!

- - -

## Training the linear classifier

Once you have preprocessed your training data in training mode and some
evaluation data in evaluation mode, you can use it to train the
TensorFlow classifier. For this, whether your run your training
job locally or on Google Cloud Platform, you will be using [this
code](./trainer/task.py).

### Command line arguments

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

### Training locally

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

### Training in the cloud

Make sure that you have enabled MLEngine. Decide upon a name for your training
job, and store it under the `JOB` environment variable. Then:
```
gcloud ml-engine jobs submit training $JOB --stream-logs --runtime-version 1.2 \
  --job-dir $JOB_DIR \
  --module-name trainer.task --package-path trainer --region "us-central1" \
  -- --train-dir $TRAIN_DIR --eval-dir $EVAL_DIR
```

(Note, the extra `--` on the last line of the command above is not a typo. That is
the pattern used in the `gcloud` command to signify that all subsequent
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

## Serving the trained classifier on Cloud ML Engine

### Finding saved models

The trainer exports saved models to the following directory:
```
$JOB_DIR/export/Servo/
```
where `$JOB_DIR` is the directory you passed as the `--job-dir` argument to the
trainer (as in the previous section).

Within the `Servo` directory, models are stored in models are stored in folders
named by the epoch time at which they were exported.

### Hosting on Cloud ML Engine

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
the `sparky` model. Assuming that `MODEL_EXPORT=$JOB_DIR/export/Servo/<most recent
timestamp>` be the location of the saved model, you can create version `alpha`
from your command line by:
```
$ gcloud ml-engine versions create "alpha" --model=sparky --origin=$MODEL_EXPORT
```

### Making predictions

In order to make predictions using this hosted model, we have to apply the same
preprocessing to the input data that we applied when we trained the model. In
this version of the guide, we explicitly only show how to do this in the case of
batch predictions. In the next version of the guide, we will show how this can
be done for online predictions using structured streaming in Spark.

As a stopgap, one could also use the model artifacts exported by the Spark training
job (the CSV file of categorical value counts stored on the path specified by
the `-x` argument to the Spark job) to manually preprocess a data stream and
perform [online prediction using Cloud Machine Learning
Engine](https://cloud.google.com/ml-engine/docs/concepts/prediction-overview#online_prediction_versus_batch_prediction).

#### Batch prediction

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
$ gcloud ml-engine jobs submit prediction sparky_alpha_1 --model=sparky --version=alpha \
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
