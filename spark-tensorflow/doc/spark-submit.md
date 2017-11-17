# Submitting a Spark Preprocessing job

Let us assume that the input data is stored under the path
`$BASE_DIR/$CRITEO_DATASET` and that we want the `.tfrecords` files to be
written to `$BASE_DIR/$OUTPUT_DIR`.

Let us set `MODE=analyze`, `MODE=transform`

Mode `analyze` use training data to preprocess the data and create
artifacts for either the `transform` step or to be fed directly 
into the TF graph. The artifacts created are the average value
of each integer feature (which is used to replace nulls), or the
rank of each feature value for the categorical features, which 
is used as the categorical value in the TF graph.


### Local preprocessing

```
$ spark-submit --master local --class \
com.google.cloud.ml.samples.criteo.CriteoPreprocessingApplication \
--packages com.github.scopt:scopt_2.11:3.6.0 --jars \
"$SPARK_TF_CONNECTOR_JAR" $CRITEO_JAR --base $BASE_DIR \
--in $CRITEO_DATASET --out $OUTPUT_DIR -m $MODE 
```

### Cloud preprocessing

Alternatively, you can use [Dataproc](https://cloud.google.com/dataproc/docs/)
to perform preprocessing in the cloud.

Begin by [creating a Dataproc
cluster](https://cloud.google.com/dataproc/docs/guides/create-cluster). Store
its name as `CLUSTER=<name of your Dataproc cluster>`.

Make sure that your data lives in a Google Cloud Storage bucket accessible to
your Dataproc cluster as described in the [Prerequisites](./prereqs.md). Store
the bucket URL under the `BUCKET` variable, and let the `CRITEO_DATASET` and
`OUTPUT_DIR` variables be defined above relative to the GCS bucket URL.

Then:
```
$ gcloud dataproc jobs submit spark --cluster $CLUSTER \
--properties spark.jars.packages=com.github.scopt:scopt_2.11:3.6.0 \
--jars "$SPARK_TF_CONNECTOR_JAR,$CRITEO_JAR" \
--class "com.google.cloud.ml.samples.criteo.CriteoPreprocessingApplication" \
-- \
-b $BUCKET -i $CRITEO_DATASET -o $OUTPUT_DIR -m $MODE -x 
```

- - -

[Home](../README.md)
