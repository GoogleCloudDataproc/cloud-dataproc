## Setup Instructions

### Before you start - Test and Compile

#### Scala (Spark)

Add the following plugin to your project plugins.sbt
```console
addSbtPlugin("org.jetbrains" % "sbt-ide-settings" % "1.1.0")
addSbtPlugin("com.eed3si9n" % "sbt-assembly" % "1.1.0")
addSbtPlugin("org.scoverage" % "sbt-scoverage" % "1.9.3")
```
Configure your project build.properties
```console
sbt.version = 1.6.1
```
Run Scala unit tests from the sbt shell:
```console
# sbt shell
test                       # test all sub-projects
create-dataset / test      # test create-dataset sub-project
streaming-kafka-gcs / test # test streaming-kafka-gcs sub-project
batch-gcs-gcs / test       # test batch-gcs-gcs sub-project
batch-gcs-bq / test        # test batch-gcs-bq sub-project
```
Assembly .jar from the sbt shell:
```console
# sbt shell
assembly                       # assembly all sub-projects
create-dataset / assembly      # assembly create-dataset sub-project
streaming-kafka-gcs / assembly # assembly streaming-kafka-gcs sub-project
batch-gcs-gcs / assembly       # assembly batch-gcs-gcs sub-project
batch-gcs-bq / assembly        # assembly batch-gcs-bq sub-project
```
The result is the following .jar:
```console
ls dataproc/create-dataset/target/scala-2.12/create-dataset-assembly-0.1.jar
ls dataproc/streaming-kafka-gcs/target/scala-2.12/streaming-kafka-gcs-assembly-0.1.jar
ls dataproc/batch-gcs-gcs/target/scala-2.12/batch-gcs-gcs-assembly-0.1.jar
ls dataproc/batch-gcs-bq/target/scala-2.12/batch-gcs-bq-assembly-0.1.jar
```

#### Python (Airflow)

Run Python integrity test to test the Airflow DAGs:
```console
# cd into the composer src folder
cd composer/src/

# copy dags to your local airflow dags folder:
cp -r dags/* ${AIRFLOW_HOME}/dags/

# run tests
python -m pytest -W ignore::DeprecationWarning -s test
```

#### Appendix: setup Airflow local environment

```console
pip install "apache-airflow[celery]==2.2.3" --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-2.2.3/constraints-3.8.txt"
pip install apache-airflow-providers-google pytest
export AIRFLOW_HOME=~/airflow/ # or other airflow home
airflow db init
airflow variables set PROJECT_ID ${PROJECT_ID}
airflow variables set REGION ${REGION}
```