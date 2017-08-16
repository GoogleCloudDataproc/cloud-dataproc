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

import org.apache.spark.sql._
import org.apache.spark.sql.functions.avg

/**
 * Missing replacer replaces all null values in a Datframe with empty strings,
 * and replaces missing integer values with the average of all integer
 * in that column.
 *
 * @param spark Spark session
**/
class CriteoMissingReplacer(val artifactExporter: ArtifactExporter)
                           (implicit val spark: SparkSession) {
  import spark.implicits._

  def preprocessCriteoFeatures(df: DataFrame, integerFeatures: Seq[String]): DataFrame = {
    val filledDf = df.na.fill("", df.columns)

    averageIntegerFeatures(filledDf, integerFeatures)
  }

  def averageIntegerFeatures(to_average_df: DataFrame, features: Seq[String]): DataFrame = {

    val integerFeaturesDf = to_average_df.
      select(features.head, features.tail: _*).
      toDF

    val averages = integerFeaturesDf.
      columns.
      map { col_name =>
        val avg_col = integerFeaturesDf.select(avg($"$col_name"))
        (col_name, avg_col)
      }.toMap

    averages.foreach { case (col: String, df: DataFrame) =>
      artifactExporter.export(col, df)
    }

    integerFeaturesDf.columns.
      foldLeft(to_average_df)((df, col) => {
        df.na.replace(
          col,
          Map("" -> averages(col).head().getDouble(0).toString)
        )
      })
  }

  def apply(df: DataFrame, integerFeatures: Seq[String]): DataFrame = {
    preprocessCriteoFeatures(df, integerFeatures)
  }
}
