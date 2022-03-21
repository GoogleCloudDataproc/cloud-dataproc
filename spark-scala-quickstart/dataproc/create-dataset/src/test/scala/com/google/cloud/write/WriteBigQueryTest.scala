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

import org.apache.spark.sql.functions.col
import org.apache.spark.sql.{DataFrame, DataFrameWriter, Row, SparkSession}
import org.mockito.ArgumentMatchers.{any, anyString}
import org.mockito.MockitoSugar
import org.scalatest.funsuite.AnyFunSuite

class WriteBigQueryTest extends AnyFunSuite with MockitoSugar {

  test("Should write to BigQuery (indirect)") {

    val mockWriter = mock[DataFrameWriter[Row]]
    val mockDf = mock[DataFrame]

    val writeBigQuery = new WriteBigQuery()

    when(mockDf.withColumn("date_partition", col("date"))) thenReturn mockDf
    when(mockDf.write) thenReturn mockWriter
    when(mockWriter.format("bigquery")) thenReturn mockWriter
    when(mockWriter.option("writeMethod", "indirect")) thenReturn mockWriter
    when(mockWriter.mode("overwrite") ) thenReturn mockWriter
    when(mockWriter.option("temporaryGcsBucket", "/any")) thenReturn mockWriter
    when(mockWriter.option("partitionField", "date_partition")) thenReturn mockWriter
    doNothing.when(mockWriter).save( anyString())

    writeBigQuery.writeIndirect(mockDf, "table", "/any")

    verify(mockWriter).save("table")

  }

}