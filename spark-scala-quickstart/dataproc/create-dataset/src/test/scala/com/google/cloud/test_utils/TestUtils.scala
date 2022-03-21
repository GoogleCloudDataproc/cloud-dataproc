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
package com.google.cloud.test_utils

import com.google.cloud.SparkSessionTestWrapper
import org.apache.spark.sql.DataFrame
import org.scalatest.funsuite.AnyFunSuite

object TestUtils extends AnyFunSuite with SparkSessionTestWrapper {

  val inputPath: String = getClass.getClassLoader.getResource("input.csv").getPath
  val outputPath: String = getClass.getClassLoader.getResource("output.csv").getPath

  def getInputDF: DataFrame = {
    sparkSession.read
        .format("csv")
        .option("header", "true")
        .option("delimiter", "|")
        .option("inferSchema", "true")
        .load(inputPath)
  }

  def getOutputDF: DataFrame = {
    sparkSession.read
        .format("csv")
        .option("header", "true")
        .option("delimiter", "|")
        .option("inferSchema", "true")
        .load(outputPath)
  }

  def assertDFEqual(df1: DataFrame, df2: DataFrame): Boolean = {
    val data1 = df1.collect()
    val data2 = df2.collect()
    data1.diff(data2).isEmpty
  }

}
