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

import org.scalatest._

import org.apache.spark.sql._

class TrainingIndexerTest extends FlatSpec with SparkSpec with GivenWhenThen with Matchers {

  trait TestFixture {
    val indexer: CriteoIndexer
    val trainingDf: DataFrame
    val result: DataFrame
    val transformedData: Array[Seq[Any]]
    val artifactExporter: EmptyArtifactExporter
  }

  private var _fixture: Option[TestFixture] = None

  private def fixture: TestFixture = _fixture match {
    case None =>
      val f = new TestFixture {
        val features = CriteoFeatures()
        val artifactExporter = new EmptyArtifactExporter()
        val indexer = new TrainingIndexer(features)

        val firstCatInput: String = features.categoricalRawLabels.head

        // Creating training data as a Seq of Row objects.
        // First five rows will have "abc" as value of first categorical column and "0" in every
        // other column

        val rows1to5 = (1 to 5).map(_ => features.inputLabels.map(_ match {
          case `firstCatInput` => "abc"
          case _ => "0"
        }))

        // The next three rows will have "xyz" as value of first categorical column and "0" in every
        // other column
        val rows6to8 = (1 to 3).map(_ => features.inputLabels.map({
          case `firstCatInput` => "xyz"
          case _ => "0"
        }))

        // The final two rows will have empty values in the first categorical column and have "0" in
        // every other column
        val rows9and10 = (1 to 2).map(_ => features.inputLabels.map({
          case `firstCatInput` => ""
          case _ => "0"
        }))

        val trainingDataSeq = rows1to5 ++ rows6to8 ++ rows9and10
        val trainingData: Seq[Row] = trainingDataSeq map {v => Row.fromSeq(v)}

        val importer = new TestImporter(trainingData, features.inputSchema)
        val trainingDf = importer.criteoImport

        val result: DataFrame = indexer.getCategoricalFeatureValueCounts(trainingDf)

        val fakeExporter = new TestExporter
        fakeExporter.criteoExport(result)
        val transformedData = fakeExporter.exported.get
      }

      _fixture = Some(f)

      f

    case Some(f) => f
  }

  behavior of "TrainingIndexer"

  it should "yield a DataFrame with the same number of rows as its input DataFrame" in {
    val f = fixture
    assert(f.result.count == f.trainingDf.count)
  }

  /*
  TODO: move t otest for CriteoAnalyzer
  it should "export vocabulary counts for each categorical feature in the training data" in {
    val f = fixture

    // 3 tokens for first categorical feature, and only 1 for the other 25
    val vocabularyRows = 25 + 3
    println("CHECK~!" +f.artifactExporter.exported.get.length)

    assert(f.artifactExporter.exported match {
      case Some(data) => data.length == vocabularyRows
      case _ => false
    })
  }*/

  it should "correctly transform the input dataframe" in {
    val f = fixture

    f.transformedData.foreach(row => {
      assert(row.length == 40)
    })
  }
}
