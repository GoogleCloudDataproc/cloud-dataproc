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
import org.scalatest.{FlatSpec, GivenWhenThen, Matchers}
import org.apache.spark.sql.{DataFrame, Row}
import org.apache.spark.sql.types.{StringType, StructField, StructType}

import scala.util.Try


class CriteoMissingReplacerTest
  extends FlatSpec with SparkSpec with GivenWhenThen with Matchers
      {

  private def hasColumn(df: DataFrame, path: String): Boolean = Try(df(path)).isSuccess


  trait TestFixture {
    val replacer: CriteoMissingReplacer
  }

  private var _fixture: Option[TestFixture] = None

  private def fixture: TestFixture = _fixture match {
    case None =>
      val f = new TestFixture {
        val features = CriteoFeatures()
        val replacer = new CriteoMissingReplacer()
      }

      _fixture = Some(f)

      f

    case Some(f) => f
  }


  behavior of "Missing Replacer"

  it should "replace missing ints with average" in {
    val f = fixture

    val dataSeq = Seq(
      Seq("1", "5", "a"),
      Seq(null, "", "b"),
      Seq("10", "13", "c"),
      Seq("12", "14", "d")
    )

    val trainingData: Seq[Row] = dataSeq map {v => Row.fromSeq(v)}
    val schema = StructType(Seq(
      StructField("a", StringType),
      StructField("b", StringType),
      StructField("c", StringType)
    ))

    val df = spark.createDataFrame(trainingData.asJava, schema)

    val integerFeatures = Seq("a", "b")
    val averageFeaturesMap = f.replacer.getAverageIntegerFeatures(df, integerFeatures)

    val averagedDf = f.replacer.replaceIntegerFeatures(df, integerFeatures, averageFeaturesMap)
    hasColumn(averagedDf, "c") should be(true)

    val df_seq = averagedDf.select("a", "b").collect.map(_.toSeq)
    val df_seq_str = df_seq.map(_.map(n => n.asInstanceOf[String]))
    val df_seq_doub = df_seq_str.map(_.map(n => n.toDouble))

    val first_col_expected_avg = ((1 + 10 + 12).toDouble) / 3
    val second_col_expected_avg = ((5 + 13 + 14).toDouble) / 3
    val Eps = 1e-3
    val first_column_avg = df_seq_doub(1)(0)
    val second_column_avg = df_seq_doub(1)(1)

    first_column_avg should equal(first_col_expected_avg +- Eps)
    second_column_avg should equal(second_col_expected_avg +- Eps)

    df_seq.foreach(row => {
      val nonulls = row.filter(_ != null)
      row.length should equal(nonulls.length)

      val noblanks = row.filter(_ != "")
      row.length should equal(noblanks.length)
    })
  }
}

