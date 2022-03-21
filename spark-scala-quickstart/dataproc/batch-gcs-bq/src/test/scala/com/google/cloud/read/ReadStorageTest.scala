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
package com.google.cloud.read

import org.apache.spark.sql.{DataFrameReader, SparkSession}
import org.mockito.MockitoSugar
import org.scalatest.funsuite.AnyFunSuite

class ReadStorageTest extends AnyFunSuite with MockitoSugar {

  test("Should read parquet") {

    val mockSparkSession = mock[SparkSession]
    val mockReader = mock[DataFrameReader]

    val readStorage = new ReadStorage(mockSparkSession)

    when(mockSparkSession.read) thenReturn mockReader
    readStorage.read("/any")

    verify(mockReader).parquet("/any")

  }

}
