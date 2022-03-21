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

import org.apache.spark.sql.DataFrame
import org.apache.spark.sql.functions.{col, current_date, current_timestamp, explode, split, window}

object Transform {

  def transform(dataFrame: DataFrame, watermark: String, windowDuration: String): DataFrame = {

    return dataFrame.select(explode(split(col("value"), " ")).alias("words"))
      .withColumn("timestamp", current_timestamp())
      .withWatermark("timestamp", watermark)
      .groupBy(window(col("timestamp"), windowDuration), col("words"))
      .count()
      .withColumn("timestamp", current_timestamp())
      .withColumn("date", current_date())

  }

}
