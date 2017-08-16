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

import scala.collection.JavaConverters._

import org.apache.spark.sql._
import org.apache.spark.sql.types.StructType

trait CriteoImporter {
  def criteoImport: DataFrame
}

class CleanTSVImporter(val inputPath: String, val schema: StructType, val numPartitions: Int)
                      (implicit val spark: SparkSession)
  extends CriteoImporter
{
  def criteoImport: DataFrame = {
    val rawDf = spark.read.format("csv").
      option("sep", "\t").
      schema(schema).
      load(inputPath).
      repartition(numPartitions)

    rawDf.na.fill("", rawDf.columns)
  }
}

class CleanTSVStreamImporter(val inputPath: String, val schema: StructType)
                            (implicit val spark: SparkSession)
  extends CriteoImporter
{
  def criteoImport: DataFrame = {
    val rawDf = spark.readStream.format("csv").
      option("sep", "\t").
      schema(schema).
      load(inputPath)

    rawDf.na.fill("", rawDf.columns)
  }
}

class TestImporter(val data: Seq[Row], val schema: StructType)
                  (implicit val spark: SparkSession)
  extends CriteoImporter
{
  def criteoImport: DataFrame = spark.createDataFrame(data.asJava, schema)
}
