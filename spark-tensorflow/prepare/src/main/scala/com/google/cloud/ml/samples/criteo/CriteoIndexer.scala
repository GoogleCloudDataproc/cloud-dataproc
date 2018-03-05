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
import org.apache.spark.sql.types._

object IndexerModelSchema {
  val schema = StructType(Seq(StructField("feature", StringType),
    StructField("value", StringType),
    StructField("count", LongType)))
}

trait CriteoIndexer {
  type IndexerResource

  def features: CriteoFeatures

  implicit val spark: SparkSession

  import spark.implicits._

  /**
   * Creates a DataFrame containing the count of each value for each feature
   *
   * @return A DataFrame with three columns: "feature" (specifies categorical feature), "value"
   *         (specifies a particular value for that feature), and "count" (specifies number of times
   *         that value appeared for that feature in the training data).
   */
  def getCategoricalFeatureValueCounts(resource: IndexerResource): DataFrame

  /**
   * Constructs an embedding from the set of feature values to the positive integers for each of
   * the feature columns in a Criteo data set. Expects to be provided with value counts for each
   * of the features.
   *
   * @param categoricalFeatureValueCounts Value counts as provided by the
   *                                      `categoricalColumnValueCounts` method.
   * @return Map from feature name to embedding table DataFrame. Columns in each DataFrame are
   *         "value", "index".
   */
  def getCategoricalColumnVocabularies(categoricalFeatureValueCounts: DataFrame):
  Map[String, DataFrame] =
    features.categoricalRawLabels.map(label => {
      (label, spark.createDataFrame(
        categoricalFeatureValueCounts.
          filter($"feature" === label).
          rdd.
          map(row => row.get(1)).
          zipWithIndex.map(pair => Row(pair._1, pair._2)),
        StructType(Seq(
          StructField("value-" ++ label, StringType),
          StructField("index-" ++ label, LongType)))
      ))
    }).toMap
}


class TrainingIndexer(val features: CriteoFeatures)
                     (implicit val spark: SparkSession)
  extends CriteoIndexer {

  import spark.implicits._

  type IndexerResource = DataFrame

  def getCategoricalFeatureValueCounts(df: DataFrame): DataFrame = {
    val categoricalRawLabels = spark.sparkContext.broadcast(features.categoricalRawLabels)

    // categoricalValues tabulates each observed feature value tagged by feature, with repetition
    val categoricalValues = df.flatMap(row => {
      categoricalRawLabels.value.
        map { label => (label, row.getAs[String](label)) }
    }).toDF("feature", "value")

    val vocabularies = categoricalValues.
      groupBy("feature", "value").
      count.
      toDF("feature", "value", "count").
      sort("count")

    vocabularies.cache()

    vocabularies
  }
}
