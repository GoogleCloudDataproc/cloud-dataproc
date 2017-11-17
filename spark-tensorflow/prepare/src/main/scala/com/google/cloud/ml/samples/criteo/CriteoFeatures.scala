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

import org.apache.spark.sql.types.{StringType, StructField, StructType}

/**
 * CriteoFeatures objects maintain information about the features to be preprocessed in a Criteo
 * data set.
 */
case class CriteoFeatures() {
  val integerFeatureLabels: Seq[String] = (1 to 13).map(index => s"integer-feature-$index")
  val categoricalFeatureLabels: Seq[String] = (1 to 26).map(index => s"categorical-feature-$index")
  val categoricalRawLabels: Seq[String] = categoricalFeatureLabels.map({label => label + "-raw"})
  val clickedLabel = Seq("clicked")

  val inputLabels: Seq[String] = clickedLabel ++ integerFeatureLabels ++ categoricalRawLabels

  val integralColumns: Seq[String] = inputLabels.
    filterNot(label => categoricalRawLabels.contains(label))

  // Correspondence between labels in the input data and labels in the preprocessed data
  val categoricalLabelMap: Map[String, String] =
    Map(categoricalRawLabels.zip(categoricalFeatureLabels): _*)

  // DataFrame schema of the input data
  val inputSchema: StructType = StructType(inputLabels.map(StructField(_, StringType)))

  val outputLabels: Seq[String] = clickedLabel ++ integerFeatureLabels ++ categoricalFeatureLabels
}
