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

import org.apache.spark.sql._

trait CriteoExporter {
  def criteoExport(df: DataFrame): Unit
}


class FileExporter(val outputPath: String, val format: String)
                  (implicit val spark: SparkSession)
extends CriteoExporter
{
  def criteoExport(df: DataFrame): Unit = df.write.format(format).save(outputPath)
}


class FileStreamExporter(val outputPath: String, val format: String)
                        (implicit val spark: SparkSession)
extends CriteoExporter
{
  def criteoExport(df: DataFrame): Unit = df.writeStream.format(format).
    option("checkpointLocation", outputPath ++ "/checkpoints").
    start(outputPath).awaitTermination()
}


class TestExporter extends CriteoExporter {
  var exported: Option[Array[Seq[Any]]] = None

  def criteoExport(df: DataFrame): Unit = {
    exported = Some(df.collect.map(_.toSeq.map(_.toString)))
  }
}
