# Packaging the Criteo preprocessor

Before we can preprocess the Criteo data, we must package our Spark script into
a JAR file, as well as the `spark-tensorflow-connector` and the
[scopt](https://github.com/scopt/scopt) library, which we use to parse arguments
to our Spark script. We will submit the JAR files for these three components to
our Spark cluster together in order to run preprocessing jobs.

This is as simple as going to the [preprocessor directory](../prepare) and
running:
`$ sbt clean package`

This will create a JAR file whose path (relative to the root directory for this
project) is `prepare/target/scala-2.11/criteo-prepare_2.11-1.0.jar`. Let us set
the variable
```
$ CRITEO_JAR=prepare/target/scala-2.11/criteo-prepare_2.11-1.0.jar
```

## spark-tensorflow-connector

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

## scopt

We will use [scopt](https://github.com/scopt/scopt) to process arguments to our
Spark script. We will provide the package information to Spark when we run the
job.

- - -

[Home](../README.md)
