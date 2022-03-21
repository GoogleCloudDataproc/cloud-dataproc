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

import com.google.cloud.read.ReadRaw
import com.google.cloud.transform.Transform
import com.google.cloud.util.Parser.{MainArguments, mainParser}
import com.google.cloud.write.{WriteBigQuery, WriteStorage}
import org.apache.spark.SparkConf
import org.apache.spark.sql.SparkSession

object CreateDataset extends SparkSessionWrapper {

  val appName = "CreateDataset"

  val readRaw = new ReadRaw(sparkSession)
  val writeBigQuery = new WriteBigQuery()
  val writeStorage = new WriteStorage()

  // Main
  def main(args: Array[String]): Unit = {

    mainParser.parse(args, MainArguments()) match {
      case Some(arguments) => {
        runETL(arguments, readRaw, writeStorage, writeBigQuery)
      }
      case None =>
    }

  }

  def runETL(args: MainArguments, readRaw: ReadRaw, writeStorage: WriteStorage, writeBigQuery: WriteBigQuery): Unit = {

    // Extract / Read
    val inputDf = readRaw.read(args.rawCsv)
    // Transform
    val outputDf = Transform.transform(inputDf)
    // Load / Write
    writeStorage.write(inputDf, args.inputParquet)
    writeStorage.write(outputDf, args.outputParquet)
    writeBigQuery.writeIndirect(inputDf, args.inputTable, args.temporaryGcsBucketPath)
    writeBigQuery.writeIndirect(outputDf, args.outputTable, args.temporaryGcsBucketPath)

  }

}
