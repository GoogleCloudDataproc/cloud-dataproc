/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.google.cloud

import com.google.cloud.read.KafkaConsumer
import com.google.cloud.transform.Transform
import com.google.cloud.util.Parser.MainArguments
import com.google.cloud.write.WriteStorage
import org.apache.spark.SparkConf
import org.apache.spark.sql.SparkSession
import com.google.cloud.util.Parser.{MainArguments, mainParser}

object StreamingExample extends SparkSessionWrapper {

  val appName = "StreamingExample"

  val kafkaConsumer = new KafkaConsumer(sparkSession)
  val writeStorage = new WriteStorage()

  // Main
  def main(args: Array[String]): Unit = {

    mainParser.parse(args, MainArguments()) match {
      case Some(arguments) => {
        runETL(arguments, kafkaConsumer, writeStorage)
      }
      case None =>
    }

  }

  def runETL(args: MainArguments, kafkaConsumer: KafkaConsumer, writeStorage: WriteStorage): Unit = {

    // Extract / Read
    val inputDf = kafkaConsumer.consume(args.brokers, args.topic)
    // Transform
    val outputDf = Transform.transform(inputDf, args.watermark, args.windowDuration)
    // Load / Write
    writeStorage.write(outputDf, args.outputPath, args.checkpointPath, args.triggerProcTime)

  }
}
