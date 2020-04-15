# Google Cloud Dataproc

This repository contains code and documentation for use with
[Google Cloud Dataproc](https://cloud.google.com/dataproc/).

## Samples in this Repository
 * `codelabs/opencv-haarcascade` provides the source code for the [OpenCV Dataproc Codelab](https://codelabs.developers.google.com/codelabs/cloud-dataproc-opencv/index.html), which demonstrates a Spark job that adds facial detection to a set of images. 
* `codelabs/spark-bigquery` provides the source code for the [PySpark for Preprocessing BigQuery Data  Codelab](https://codelabs.developers.google.com/codelabs/pyspark-bigquery/index.html), which demonstrates using PySpark on Cloud Dataproc to process data from BigQuery.
* `codelabs/spark-nlp` provides the source code for the [PySpark for Natural Language Processing Codelab](https://codelabs.developers.google.com/codelabs/spark-nlp/index.html), which demonstrates using [spark-nlp](https://github.com/JohnSnowLabs/spark-nlp) library for Natural Language Processing.
* `notebooks/python` provides example Jupyter notebooks to demonstrate using PySpark with the [BigQuery Storage Connector](https://github.com/GoogleCloudPlatform/spark-bigquery-connector) and the [Spark GCS Connector](https://github.com/GoogleCloudPlatform/bigdata-interop/tree/master/gcs)
 * `spark-tensorflow` provides an example of using Spark as a preprocessing toolchain for Tensorflow jobs. Optionally,
 it demonstrates the [spark-tensorflow-connector](https://github.com/tensorflow/ecosystem/tree/master/spark/spark-tensorflow-connector) to convert CSV files to TFRecords.
 * `spark-translate` provides a simple demo Spark application that translates words using Google's Translation API and running on Cloud Dataproc.

See each directories README for more information.


## Additional Dataproc Repositories

You can find more Dataproc resources in these github repositories:

### Dataproc projects
* [Dataproc initialization
  actions](https://github.com/GoogleCloudPlatform/dataproc-initialization-actions)
* [GCP Token Broker](https://github.com/GoogleCloudPlatform/gcp-token-broker)
* [Dataproc Custom Images](https://github.com/GoogleCloudPlatform/dataproc-custom-images)
* [Dataproc Spawner](https://github.com/GoogleCloudPlatform/dataprocspawner)

### Connectors
* [Hadoop/Spark GCS Connector](https://github.com/GoogleCloudPlatform/bigdata-interop/tree/master/gcs)
* [Spark BigQuery Connector](https://github.com/GoogleCloudPlatform/spark-bigquery-connector)
* [Hadoop BigQuery Connector](https://github.com/GoogleCloudPlatform/bigdata-interop/tree/master/bigquery)
* [Spark Pubsub Connector](https://github.com/GoogleCloudPlatform/bigdata-interop/tree/master/pubsub)
* [Spark Spanner Connector](https://github.com/GoogleCloudPlatform/cloud-spanner-spark-connector)
* [Hive Bigquery Storage Handler](https://github.com/GoogleCloudPlatform/hive-bigquery-storage-handler)

### Kubernetes Operators
* [Spark kubernetes operator](https://github.com/GoogleCloudPlatform/spark-on-k8s-operator)
* [Flink kubernetes operator](https://github.com/GoogleCloudPlatform/flink-on-k8s-operator)

### Examples
* [Dataproc Python
  examples](https://github.com/GoogleCloudPlatform/python-docs-samples/tree/master/dataproc)
* [Dataproc Pubsub Spark Streaming example](https://github.com/GoogleCloudPlatform/dataproc-pubsub-spark-streaming)
* [Dataproc Java Bigtable sample](https://github.com/GoogleCloudPlatform/cloud-bigtable-examples/tree/master/java/dataproc-wordcount)
* [Dataproc Spark-Bigtable samples](https://github.com/GoogleCloudPlatform/cloud-bigtable-examples/tree/master/scala)

## For more information
For more information, review the [Dataproc
documentation](https://cloud.google.com/dataproc/docs/). You can also
pose questions to the [Stack
Overflow](http://stackoverflow.com/questions/tagged/google-cloud-dataproc) community
with the tag `google-cloud-dataproc`.
See our other [Google Cloud Platform github
repos](https://github.com/GoogleCloudPlatform) for sample applications and
scaffolding for other frameworks and use cases.

## Contributing changes

* See [CONTRIBUTING.md](CONTRIBUTING.md)

## Licensing

* See [LICENSE](LICENSE)
