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

class WriteStorage {

  def write(dataFrame: DataFrame, pathParquet: String): Unit = {

    dataFrame
      .withColumn("date_partition", col("date"))
      .write
      .mode("overwrite") // if path already exists, overwrite
      .partitionBy("date_partition")
      .parquet(pathParquet)
  }

}