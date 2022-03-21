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
package com.google.cloud.transform

import com.google.cloud.SparkSessionTestWrapper
import com.google.cloud.test_utils.TestUtils.{assertDFEqual, getInputDF, getOutputDF}
import org.apache.spark.sql.DataFrame
import org.scalatest.funsuite.AnyFunSuite

class TransformTest extends AnyFunSuite with SparkSessionTestWrapper {

  val inputDF: DataFrame = getInputDF
  val outputDF: DataFrame = getOutputDF

  test("Should transform DF for words and count as expected") {
    val transformed = Transform.transform(inputDF).select("words","count")
    assert(assertDFEqual(transformed, outputDF.select("words","count")))
  }

}
