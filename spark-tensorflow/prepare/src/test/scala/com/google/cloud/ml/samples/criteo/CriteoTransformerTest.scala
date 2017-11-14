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

import org.scalatest.{FlatSpec, GivenWhenThen, Matchers}

import org.apache.spark.sql.{DataFrame, Row}

class CriteoTransformerTest extends FlatSpec with SparkSpec with GivenWhenThen with Matchers{

  trait TestFixture {
    val indexer: TrainingIndexer
    val trainingDf: DataFrame
    val result: DataFrame
    val artifactExporter: EmptyArtifactExporter
    val features: CriteoFeatures
    val transformer: CriteoTransformer
  }

  private var _fixture: Option[TestFixture] = None

  private def fixture: TestFixture = _fixture match {
    case None =>
      val f = new TestFixture {
        val features = CriteoFeatures()

        // Creating training data as a Seq of Row objects.
        // First five rows will have "abc" as value of first categorical column and "0" in every
        // other column
        val firstCatInput: String = features.categoricalRawLabels.head
        val firstIntInput: String = features.integerFeatureLabels.head

        val rows1to5 = (1 to 5).map(_ => features.inputLabels.map(_ match {
          case `firstCatInput` => "abc"
          case `firstIntInput` => "3"
          case _ => "0"
        }))


        // The next three rows will have "xyz" as value of first categorical column and "0" in every
        // other column
        val rows6to8 = (1 to 3).map(_ => features.inputLabels.map({
          case `firstCatInput` => "xyz"
          case `firstIntInput` => ""
          case _ => "0"
        }))

        // The final two rows will have empty values in the first categorical column and have "0" in
        // every other column
        val rows9and10 = (1 to 2).map(_ => features.inputLabels.map({
          case `firstCatInput` => "null"
          case `firstIntInput` => "3"
          case _ => "0"
        }))

        val trainingDataSeq = rows1to5 ++ rows6to8 ++ rows9and10
        val trainingData: Seq[Row] = trainingDataSeq map {v => Row.fromSeq(v)}

        val trainingDf = spark.createDataFrame(spark.sparkContext.parallelize(trainingData),
          features.inputSchema)

        val artifactExporter = new EmptyArtifactExporter()
        val indexer = new TrainingIndexer(features)

        val valueCounts = indexer.getCategoricalFeatureValueCounts(trainingDf)
        val vocabularies = indexer.getCategoricalColumnVocabularies(valueCounts)
        val vocabularyImporter = new TestVocabularyImporter(vocabularies)
        val transformer = new CriteoTransformer("", features, 1,
          indexer, "", vocabularyImporter)


        val result: DataFrame = transformer(trainingDf)
      }

      _fixture = Some(f)

      f

    case Some(f) => f
  }

  behavior of "CriteoTransformer"

  it should "yield a DataFrame with the same number of rows as its input DataFrame" in {
    val f = fixture
    assert(f.result.count == f.trainingDf.count)
  }

  it should "verify add rank features works" in {
    val f = fixture

    val headLabel = f.features.categoricalRawLabels.head
    val valueCounts = f.indexer.getCategoricalFeatureValueCounts(f.trainingDf)
    val vocabularies = f.indexer.getCategoricalColumnVocabularies(valueCounts)

    val withRank = f.transformer.addRankFeatures(f.trainingDf, vocabularies)
    }

  it should "replace missing integer features" in {
    val f = fixture
    val intFeature = f.features.integerFeatureLabels.head
    f.result.filter(s"`$intFeature` is null").count() should equal(0)
  }

}
