This example is a simple demo Spark application that translates words using
Google's Translation API and running on Cloud Dataproc.

## Prerequesites

1. You are familiar with [scala](http://scala-lang.org/) and have [Maven](https://maven.apache.org/) and/or [SBT](http://www.scala-sbt.org/) installed. We will use scala to communicate with Spark.

2. You have the [Cloud SDK](https://cloud.google.com/sdk/) installed.

3. You have a Google Cloud project and have [enabled billing](https://cloud.google.com/billing/docs/how-to/modify-project).

## Running the code

1. Record the project ID in an environment variable for later use:
   ```
   export PROJECT=$(gcloud info --format='value(config.project)')
   ```

2. Enable the `translate` and `dataproc` APIs:
   ```
   gcloud services enable translate.googleapis.com dataproc.googleapis.com
   ```

3. Compile the JAR (this may take a few minutes):

* Option 1: with Maven
  ```
  cd maven
  mvn package
  ```
* Option 2: with SBT
  ```
  cd sbt
  sbt assembly
  mv target/scala-2.11/translate-example-assembly-1.0.jar target/translate-example-1.0.jar
  ```

4. Create a bucket:
   ```
   gsutil mb gs://$PROJECT-bucket
   ```

5. Upload `words.txt` to the bucket:
   ```
   gsutil cp ../words.txt gs://$PROJECT-bucket
   ```
   The file `words.txt` contains the following:
   ```
   cat
   dog
   fish
   ```

6. Create a Cloud Dataproc cluster:
   ```
   gcloud dataproc clusters create demo-cluster \
   --zone=us-central1-a \
   --scopes=cloud-platform \
   --image-version=1.3
   ```

7. Submit the Spark job to translate the words to French:
   ```
   gcloud dataproc jobs submit spark \
   --cluster demo-cluster \
   --jar target/translate-example-1.0.jar \
   -- fr gs://$PROJECT-bucket words.txt translated-fr
   ```

8. Verify that the words have been translated:
   ```
   gsutil cat gs://$PROJECT-bucket/translated-fr/part-*
   ```
   The output is:
   ```
   chat
   chien
   poisson
   ```
