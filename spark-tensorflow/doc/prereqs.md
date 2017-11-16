# Prerequisites

1. You are familiar with [Python](https://www.python.org/).

2. You have [TensorFlow set up](https://www.tensorflow.org/install/). We will
use the [Python API](https://www.tensorflow.org/api_docs/python/) to communicate
with it.

3. You have [Spark set up](https://spark.apache.org/docs/latest/) and
   you know [the basics](https://spark.apache.org/docs/latest/quick-start.html).

4. You are familiar with [scala](http://scala-lang.org/) and have [SBT](http://www.scala-sbt.org/) installed. We will use scala to communicate with Spark.

5. You have access to the [Criteo Kaggle data set](http://labs.criteo.com/2014/02/kaggle-display-advertising-challenge-dataset/). Unless you are interested in
stress testing Cloud products, I highly recommend making it smaller.

6. The data should be available to your Spark cluster. If you intend to run this
example on [Google Cloud Platform](https://cloud.google.com/), this means
putting it in Google Cloud Storage:
       a. [Sign up for free tier](https://cloud.google.com/free/) if you haven't already.
       b. [Create a project](https://cloud.google.com/resource-manager/docs/creating-managing-projects).
       c. Store your data set(s) into a [Google Cloud Storage
       bucket](https://cloud.google.com/storage/) associated with your project.
       
7. If you plan to do use [Dataproc](https://cloud.google.com/dataproc/docs/) for
   preprocessing or [Machine Learning
   Engine](https://cloud.google.com/ml-engine/docs/) for training/prediction,
   please [enable them in your
   project](https://support.google.com/cloud/answer/6158841?hl=en).

- - -

[Home](../README.md)
