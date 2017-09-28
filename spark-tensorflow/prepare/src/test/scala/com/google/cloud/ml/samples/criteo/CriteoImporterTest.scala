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

class CleanTSVImporterTest extends FlatSpec with SparkSpec with GivenWhenThen with Matchers {
  "criteoImport" should "import clean training data from a TSV file" in {
    val inputPath = "src/test/resources/test_train.csv"
    val trainFeatures = CriteoFeatures()
    val importer = new CleanTSVImporter(inputPath, trainFeatures.inputSchema, 1)

    val df = importer.criteoImport

    df.count should equal(5)

    // turn test dataframe to array to avoid serialization
    val df_seq = df.collect.map(_.toSeq)
    df_seq.foreach(row => {
        // verify all nulls are replaced by asserting
        // length without nulls is the same
        val nonulls = row.filter(_ != null)
        row.length should equal(nonulls.length)
    })
  }
}
