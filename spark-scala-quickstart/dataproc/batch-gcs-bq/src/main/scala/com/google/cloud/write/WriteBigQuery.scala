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

import org.apache.spark.sql.DataFrame
import org.apache.spark.sql.functions.col

class WriteBigQuery {

    // github.com/GoogleCloudDataproc/spark-bigquery-connector

    // partitioning and overwriting is not currently supported by direct mode
    def writeDirect (dataFrame: DataFrame, outputTable: String): Unit = {
        dataFrame
          .write
          .format("bigquery")
          .option("writeMethod", "direct") // Please refer to the data ingestion pricing page regarding the BigQuery Storage Write API pricing
          .save(outputTable)
    }

    def writeIndirect (dataFrame: DataFrame, outputTable: String, temporaryGcsBucket: String): Unit = {
        dataFrame
          .withColumn("date_partition", col("date"))
          .write
          .format("bigquery")
          .option("writeMethod", "indirect")
          .mode("overwrite") // if table already exists, overwrite
          .option("temporaryGcsBucket", temporaryGcsBucket)
          .option("partitionField", "date_partition")
          .save(outputTable)
    }

}
