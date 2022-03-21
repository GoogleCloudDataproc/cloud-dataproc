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
package com.google.cloud.write

import com.google.cloud.test_utils.TestUtils.getOutputDF
import org.apache.spark.sql.functions.col
import org.apache.spark.sql.{DataFrame, DataFrameWriter, Row, SparkSession}
import org.mockito.MockitoSugar
import org.scalatest.funsuite.AnyFunSuite

class WriteStorageTest extends AnyFunSuite with MockitoSugar {

  test("Should write parquet") {

    val mockWriter = mock[DataFrameWriter[Row]]
    val mockDf = mock[DataFrame]

    val writeStorage = new WriteStorage()

    when(mockDf.withColumn("date_partition", col("date"))) thenReturn mockDf
    when(mockDf.write) thenReturn mockWriter
    when(mockWriter.mode("overwrite") ) thenReturn mockWriter
    when(mockWriter.partitionBy("date_partition")) thenReturn mockWriter

    writeStorage.write(mockDf, "/any")

    verify(mockWriter).parquet("/any")

  }

}