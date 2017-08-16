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

import org.apache.spark.sql.SparkSession
import scopt.OptionParser


case class ClargConfig(basePath: String = "",
                       relativeInputPath: String = "",
                       relativeOutputPath: String = "",
                       mode: PreprocessingMode = Predict,
                       relativeModelPath: String = "",
                       numPartitions: Int = 500,
                       loadModel: Boolean = false)

object CriteoPreprocessingApplication {
  def main(args: Array[String]) {
    val parser = new OptionParser[ClargConfig]("Criteo TFRecord Preprocessor") {
      head("CriteoPreprocessingApplication", "1.0.0")

      help("help").text("Prints this description of the CLI to the Criteo TFRecord Preprocessor")

      opt[String]('b', "base").required.action((b, c) => c.copy(basePath = b)).text(
        "The base path along which the application should find inputs and store outputs. Required."
      )

      opt[String]('i', "in").required.action((i, c) => c.copy(relativeInputPath = i)).text(
        "The pattern relative to the base path which the input files match. Required."
      )

      opt[String]('o', "out").required.action((o, c) => c.copy(relativeOutputPath = o)).text(
        "The relative path to the directory in which the resulting TFRecord files should be stored."
      )

      opt[String]('x', "indexer").required.action((x, c) => c.copy(relativeModelPath = x)).text(
        "The path on which the model used to encode the input data either IS or SHOULD BE stored."
      )

      opt[Int]('n', "numPartitions").action((n, c) => c.copy(numPartitions = n)).text(
        "The number of partitions in which to process the input file. Default is 500."
      )

      opt[Unit]('l', "load").action((l, c) => c.copy(loadModel = true)).text(
        "Flag to denote whether model should be loaded from the given model path."
      )

      opt[String]('m', "mode").action(
        (m, c) => c.copy(mode = PreprocessingMode(m) match {
          case Some(mode) => mode
          case None =>
            throw new Exception("Illegal mode passed under -m or --mode." +
              "Pass \"train\", \"predict\", or \"evaluate\".")
        })
      ).text(
        "\"train\", \"predict\", or \"evaluate\""
      )
    }

    parser.parse(args, ClargConfig()) match {
      case Some(config) =>
        implicit val spark = SparkSession.builder().
          appName("Criteo TFRecord Preprocessor").
          getOrCreate()

        val inputPath = config.basePath ++ config.relativeInputPath
        val outputPath = config.basePath ++ config.relativeOutputPath

        val modelPath = config.basePath ++ config.relativeModelPath

        val features = CriteoFeatures(config.mode)

        val importer = config.mode match {
          case Predict => new CleanTSVStreamImporter(inputPath, features.inputSchema)
          case _ => new CleanTSVImporter(inputPath, features.inputSchema, config.numPartitions)
        }


        val exporter = config.mode match {
          case Predict => new FileStreamExporter(outputPath, "tfrecords")
          case _ => new FileExporter(outputPath, "tfrecords")
        }

        val artifactExporter = new ArtifactExporter(config.basePath ++ "artifacts/")

        val indexer: CriteoIndexer = config.mode match {
          case Train =>
            val exporter = new FileExporter(modelPath, "csv")
            new TrainingIndexer(features, artifactExporter)

          case _ =>
            val importer = new CleanTSVImporter(modelPath ++ "/*.csv", IndexerModelSchema.schema,
              config.numPartitions)
            new IndexApplier(features, importer)
        }

        val missingReplacer = new CriteoMissingReplacer(artifactExporter)

        val preprocessor =
          new CriteoPreprocessor(config.mode, importer, indexer, exporter, missingReplacer)

        preprocessor.execute()

      case None => throw new Exception("Unable to configure preprocessor")
    }
  }
}
