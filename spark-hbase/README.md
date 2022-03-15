# Google Cloud Dataproc

This folder contains code and documentation to connect to HBase from Spark job in Dataproc following steps below:

## Create a Dataproc cluster with HBase, Zookeeper installed

Create a Dataproc cluster using the –optional-components flag to install the HBase, Zookeeper optional component on the cluster and the enable-component-gateway flag to enable the Component Gateway to allow you to access the HBase Console from the Cloud Console.

* Set environment variables:
  * PROJECT: Your GCP project ID.
  * REGION: Region where the cluster used in this tutorial will be created, for example, "us-west1".
  * WORKERS: 3 - 5 workers are recommended for this tutorial. 
  * IMAGE_VERSION: Your Dataproc image version.
  * CLUSTER: Your cluster name.

* For example:

```
PROJECT=my-projectId
WORKERS=3
REGION=us-west1
IMAGE_VERSION=2.0.30-debian10
CLUSTER=dataproc-hbase-cluster
```

* Run the Google Cloud CLI on your local machine to create the cluster:

```
gcloud dataproc clusters create ${CLUSTER} \
  --project=${PROJECT} \
  --image-version=${IMAGE_VERSION} \
  --region=${REGION} \
  --num-workers=${WORKERS} \
  --optional-components=ZOOKEEPER,HBASE \
  --enable-component-gateway
```

## Create HBase table via HBase Shell

* These steps are to create the HBase table:
  * SSH to the master node of Dataproc cluster
  * Run the command to access to HBase shell: 
  
  ```
  hbase shell
  ```
  * Create HBase table with a column family:
    
  ```
  create 'my_table','cf'
  ```

## Spark code to write, read the data to HBase in Java/Python

To build the code, run the following commands from the main directory:

```
mvn clean package
```

> Note that build requires Java 8 and Maven installed

## Submit the Spark job

### Submit the Java Spark job

To submit the Java Spark job, using the command below:

```
gcloud dataproc jobs submit spark --class=hbase.SparkHBaseMain \
  --jars=spark-hbase-1.0-SNAPSHOT.jar \
  --project=${PROJECT} \
  --region=${REGION} \
  --cluster=${CLUSTER} \
  --properties='spark.driver.extraClassPath=/etc/hbase/conf:/usr/lib/hbase/*,spark.executor.extraClassPath=/etc/hbase/conf:/usr/lib/hbase/*'
```

### Submit the PySpark job

To submit the PySpark job, using the command below:

```
gcloud dataproc jobs submit pyspark --project=${PROJECT} \
  --region=${REGION} \
  --cluster=${CLUSTER} \
  --properties='spark.driver.extraClassPath=/etc/hbase/conf:/usr/lib/hbase/*,spark.executor.extraClassPath=/etc/hbase/conf:/usr/lib/hbase/*' \
  pyspark-hbase.py
```

> You need to pass the Spark properties “spark.driver.extraClassPath” and “spark.executor.extraClassPath” to add HBase configuration and HBase library to classpath. Otherwise, the job will fail with exceptions.

Alternatively, you can add above properties when creating the Dataproc cluster so that you do not need to pass properties to the Spark submit command. For example, this command to add the properties when creating the Dataproc cluster:

```
gcloud dataproc clusters create ${CLUSTER} \
  --project=${PROJECT} \
  --image-version=${IMAGE_VERSION} \
  --region=${REGION} \
  --num-workers=${WORKERS} \
  --optional-components=ZOOKEEPER,HBASE \
  --enable-component-gateway \
  --properties='spark:spark.driver.extraClassPath=/etc/hbase/conf:/usr/lib/hbase/*,spark:spark.executor.extraClassPath=/etc/hbase/conf:/usr/lib/hbase/*’
```

## Verify the data in HBase shell

After the Spark job is successfully, you can follow these steps to verify the data in HBase:
1. SSH to the master node of Dataproc cluster
2. Run the command to access to HBase Shell:

```
hbase shell
```
3. Scan the table to view the data using command:

```
scan 'my_table'
```

It should return the data:

```
ROW                           COLUMN+CELL                                                                          
key1                         column=cf:status, timestamp=1645043111980, value=foo                                 
key2                         column=cf:status, timestamp=1645043111980, value=bar
```