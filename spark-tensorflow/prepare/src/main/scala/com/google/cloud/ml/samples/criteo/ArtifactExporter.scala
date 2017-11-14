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

import org.apache.spark.sql.{DataFrame, SparkSession}


trait ArtifactExporter {
  def export(column: String, df: DataFrame)
}


class FileArtifactExporter (val outputPath: String)
                       (implicit val spark: SparkSession)
extends ArtifactExporter
{

  def export(prefix: String, df: DataFrame): Unit = {
    val fullOutputPath = outputPath + "/" + prefix
    df.repartition(1).write.format("csv").save(fullOutputPath)
  }
}

class EmptyArtifactExporter
  extends ArtifactExporter {

  var exported: Option[Array[Seq[Any]]] = None

  override def export(column: String, df: DataFrame): Unit = {
    exported = Some(df.collect.map(_.toSeq.map(_.toString)))
  }
}
