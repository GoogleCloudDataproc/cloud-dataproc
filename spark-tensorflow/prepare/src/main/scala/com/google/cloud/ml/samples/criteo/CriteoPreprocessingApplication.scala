/*
 * Copyright 2017 Google Inc. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *            http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.google.cloud.ml.samples.criteo

import org.apache.spark.sql.{DataFrame, SparkSession}
import scopt.OptionParser


/**
  * Union of the different modes in which preprocessing can be done.
  */
sealed trait PreprocessingMode

case object Analyze extends PreprocessingMode

case object Transform extends PreprocessingMode

/**
  * Converts string for mode into the appropriate `PreprocessingMode` object.
  */
object PreprocessingMode {
  def apply(specifier: String): Option[PreprocessingMode] = specifier.toLowerCase match {
    case "analyze" => Some(Analyze)
    case "transform" => Some(Transform)
    case _ => None
  }
}


case class NewClargConfig(basePath: String = "",
                          relativeInputPath: String = "",
                          relativeOutputPath: String = "",
                          mode: PreprocessingMode = Analyze,
                          numPartitions: Int = 500)

object CriteoPreprocessingApplication {

  def main(args: Array[String]) {
    val parser = new OptionParser[NewClargConfig]("Criteo TFRecord Preprocessor") {
      head("CriteoPreprocessingApplication", "1.0.0")

      help("help").text("Prints this description of the CLI to the Criteo TFRecord Preprocessor")

      opt[String]('b', "base").required.action((b, c) => c.copy(basePath = b)).text(
        "The base path along which the application should find inputs and store outputs. Required."
      )

      opt[String]('i', "in").required.action((i, c) => c.copy(relativeInputPath = i)).text(
        "The pattern relative to the base path which the input files match. Required."
      )

      opt[String]('o', "out").required.action((o, c) => c.copy(relativeOutputPath = o)).text(
        "The relative path to the directory in which the resulting transformed TFRecord files" +
          " or analyze artifacts should be stored."
      )

      opt[Int]('n', "numPartitions").action((n, c) => c.copy(numPartitions = n)).text(
        "The number of partitions in which to process the input file. Default is 500."
      )

      opt[String]('m', "mode").action(
        (m, c) => {
          val mod = PreprocessingMode(m)
          c.copy(mode =
            mod match {
              case Some(mod) => mod
              case None =>
                throw new Exception("Illegal mode passed under -m or --mode." +
                  "Pass \"analyze\", \"transform\".")
            })
        }
      ).text(
        "\"analyze\", \"transform\""
      )
    }
    parser.parse(args, NewClargConfig()) match {
      case Some(config) =>
        implicit val spark = SparkSession.builder().
          appName("Criteo TFRecord Preprocessor").
          getOrCreate()

        val inputPath = config.basePath ++ config.relativeInputPath
        val outputPath = config.basePath ++ config.relativeOutputPath
        val artifactPath = config.basePath ++ "artifacts/"

        val features = CriteoFeatures()

        val artifactExporter = config.mode match {
          case Analyze => new FileArtifactExporter(config.basePath ++ "artifacts/")
          case _ => new EmptyArtifactExporter()
        }

        val indexer = new TrainingIndexer(features)
        val importer = new CleanTSVImporter(inputPath,
          features.inputSchema,
          config.numPartitions)

        config.mode match {
          case Analyze =>
            val analyzer = new CriteoAnalyzer(inputPath, features.inputSchema,
            features, config.numPartitions, indexer, importer, artifactExporter)
            analyzer()
          case Transform =>
            val vocabularyImporter = new ArtifactVocabularyImporter(features, artifactPath)
            val exporter = new FileExporter(outputPath, "tfrecords")

            val transformer = new CriteoTransformer(inputPath,
              features, config.numPartitions, indexer,
              artifactPath, vocabularyImporter)

            val resultDf = transformer(importer.criteoImport)
            exporter.criteoExport(resultDf)
        }
    }
  }
}
