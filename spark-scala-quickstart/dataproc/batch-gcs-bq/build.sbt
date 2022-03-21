name := "batch-gcs-bq"

version := "0.1"

scalaVersion := "2.12.14"

val sparkVersion = "3.1.2"
val scoptVersion = "4.0.1"

libraryDependencies ++= Seq(
  "org.apache.spark" %% "spark-core" % sparkVersion % Provided,
  "org.apache.spark" %% "spark-sql" % sparkVersion % Provided,
  "com.github.scopt" %% "scopt" % scoptVersion,
  "com.google.cloud.spark" %% "spark-bigquery-with-dependencies" % "0.23.2",
  "org.scalatest" %% "scalatest" % "3.2.9" % "test",
  "org.mockito" %% "mockito-scala" % "1.17.5" % Test
)

ThisBuild / assemblyMergeStrategy := {
  case PathList("org", "apache", "spark", "unused", "UnusedStubClass.class") => MergeStrategy.first
  case x =>
    val currentStrategy = (ThisBuild / assemblyMergeStrategy).value
    currentStrategy(x)
}