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

import com.google.cloud.util.Parser.{MainArguments, mainParser}
import com.google.cloud.read.ReadStorage
import com.google.cloud.transform.Transform
import com.google.cloud.write.WriteBigQuery

object BatchExample extends SparkSessionWrapper {

  val appName = "BatchExample"

  val readStorage = new ReadStorage(sparkSession)
  val writeBigQuery = new WriteBigQuery()

  // Main
  def main(args: Array[String]): Unit = {

    mainParser.parse(args, MainArguments()) match {
      case Some(arguments) => {
        runETL(arguments, readStorage, writeBigQuery)
      }
      case None =>
    }

  }

  def runETL(args: MainArguments, readStorage: ReadStorage, writeBigQuery: WriteBigQuery): Unit = {

    // Extract / Read
    val inputDf = readStorage.read(args.inputPath)
    // Transform
    val outputDf = Transform.transform(inputDf)
    // Load / Write
    args.writeMode match {
      case "direct"  => writeBigQuery.writeDirect(outputDf, args.outputTable)
      case "indirect" => writeBigQuery.writeIndirect(outputDf, args.outputTable, args.temporaryGcsBucketPath)
    }
  }
}
