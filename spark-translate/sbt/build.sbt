lazy val commonSettings = Seq(
  organization := "dataproc-java-dependencies-demo",
  name := "translate-example",
  version := "1.0",
  scalaVersion := "2.11.8",
)

lazy val shaded = (project in file("."))
  .settings(commonSettings)

mainClass in (Compile, packageBin) := Some("demo.TranslateExample")

libraryDependencies ++= Seq(
  "org.apache.spark" % "spark-sql_2.11" % "2.2.1" % "provided",
  "com.google.cloud" % "google-cloud-translate" % "1.35.0"
)

assemblyShadeRules in assembly := Seq(
  ShadeRule.rename("com.google.common.**" -> "repackaged.com.google.common.@1").inAll
)