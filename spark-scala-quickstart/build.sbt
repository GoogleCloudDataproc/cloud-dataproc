name := "parent-project"

version := "0.1"

scalaVersion := "2.12.14"

val sparkVersion = "3.1.2"
val scoptVersion = "4.0.1"

lazy val commonSettings = Seq()

lazy val assemblySettings = Seq(
  assembly / assemblyJarName := name.value + "-assembly-" + version.value + ".jar",
)

// List of all dependencies used by all sub-projects
lazy val allDependencies =
  new {
    val spark_core = "org.apache.spark" %% "spark-core" % sparkVersion % Provided
    val spark_sql = "org.apache.spark" %% "spark-sql" % sparkVersion % Provided
    val scopt = "com.github.scopt" %% "scopt" % scoptVersion
    val spark_streaming = "org.apache.spark" %% "spark-streaming" % sparkVersion % Provided
    val spark_sql_kafka = "org.apache.spark" %% "spark-sql-kafka-0-10" % sparkVersion
    val spark_streaming_kafka = "org.apache.spark" %% "spark-streaming-kafka-0-10" % sparkVersion
    val spark_bigquery = "com.google.cloud.spark" %% "spark-bigquery-with-dependencies" % "0.23.2"
    val scala_test = "org.scalatest" %% "scalatest" % "3.2.9" % Test
    val mockito = "org.mockito" %% "mockito-scala" % "1.17.5" % Test
  }

// Basic common dependencies
lazy val basicDependencies = Seq(
  allDependencies.spark_core,
  allDependencies.spark_sql,
  allDependencies.scopt,
  allDependencies.scala_test,
  allDependencies.mockito
)

// Dependencies for each sub-project
lazy val createDatasetDeps = basicDependencies
lazy val streamingKafkaGcsDeps = basicDependencies ++ Seq(
  allDependencies.spark_streaming,
  allDependencies.spark_sql_kafka,
  allDependencies.spark_streaming_kafka
)
lazy val batchGcsGcsDeps = basicDependencies
lazy val batchGcsBqDeps = basicDependencies ++ Seq(
  allDependencies.spark_bigquery
)

// Definition of each sub-project
lazy val create_dataset  = Project("create-dataset", file("dataproc/create-dataset"))
  .settings(
    commonSettings,
    assemblySettings,
    name := "create-dataset",
    libraryDependencies ++= createDatasetDeps
  )
lazy val streaming_kafka_gcs  = Project("streaming-kafka-gcs", file("dataproc/streaming-kafka-gcs"))
  .settings(
    commonSettings,
    assemblySettings,
    name := "streaming-kafka-gcs",
    libraryDependencies ++= streamingKafkaGcsDeps
  )
lazy val batch_gcs_gcs  = Project("batch-gcs-gcs", file("dataproc/batch-gcs-gcs"))
  .settings(
    commonSettings,
    assemblySettings,
    name := "batch-gcs-gcs",
    libraryDependencies ++= batchGcsGcsDeps
  )
lazy val batch_gcs_bq  = Project("batch-gcs-bq", file("dataproc/batch-gcs-bq"))
  .settings(
    commonSettings,
    assemblySettings,
    name := "batch-gcs-bq",
    libraryDependencies ++= batchGcsBqDeps
  )