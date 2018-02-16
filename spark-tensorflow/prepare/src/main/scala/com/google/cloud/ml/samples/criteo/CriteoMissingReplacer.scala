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
 * Missing replacer replaces all null values in a Dataframe with empty strings,
 * and replaces missing integer values with the average of all integer
 * in that column.
 *
 * @param spark Spark session
 */
class CriteoMissingReplacer()(implicit val spark: SparkSession) {

  import spark.implicits._

  /**
   * Calculates a map of integer columns to their average values.
   *
   * @param to_average_df The DataFrame with integer columns to get averages of
   * @param features      The column names of the integer features
   * @return A map from integer column names to their averages
   */
  def getAverageIntegerFeatures(to_average_df: DataFrame,
                                features: Seq[String]): Map[String, DataFrame] = {
    val integerFeaturesDf = to_average_df.
      select(features.head, features.tail: _*).
      toDF

    integerFeaturesDf.
      columns.
      map { col_name =>
        val avg_col = integerFeaturesDf.select(avg($"$col_name"))
        (col_name, avg_col)
      }.toMap
  }

  /**
   * Replaces the integer values with their averages.
   *
   * @param toReplaceDf Dataframe with values to replace.
   * @param features    Set of integer features column names.
   * @param averages    Map of integer feature column names to their averages.
   * @return The DataFrame with null values replaced with the averages.
   */
  def replaceIntegerFeatures(toReplaceDf: DataFrame,
                             features: Seq[String],
                             averages: Map[String, DataFrame]): DataFrame = {
    val filledDf = toReplaceDf.na.fill("", features)

    features.foldLeft(filledDf)((df, col) => {
      df.na.replace(
        col,
        Map("" -> averages(col).head().getDouble(0).toString)
      )
    })
  }
}
