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

import org.apache.spark.sql.streaming.{DataStreamReader}
import org.apache.spark.sql.{DataFrame, SparkSession}
import org.mockito.MockitoSugar
import org.scalatest.funsuite.AnyFunSuite

class KafkaConsumerTest extends AnyFunSuite with MockitoSugar {

  test("Should readStream from Kafka") {

    val mockSparkSession = mock[SparkSession]
    val mockReader = mock[DataStreamReader]
    val mockDf = mock[DataFrame]

    when(mockSparkSession.readStream) thenReturn mockReader
    when(mockReader.format("kafka")) thenReturn mockReader
    when(mockReader.option("kafka.bootstrap.servers", "localhost:9092")) thenReturn mockReader
    when(mockReader.option("subscribe", "any")) thenReturn mockReader
    when(mockReader.option("includeHeaders", "true")) thenReturn mockReader
    when(mockReader.load()) thenReturn mockDf
    when(mockDf.selectExpr("CAST(key AS STRING)", "CAST(value AS STRING)", "headers")) thenReturn mockDf

    val kafkaConsumer = new KafkaConsumer(mockSparkSession)
    kafkaConsumer.consume("localhost:9092", "any")

    verify(mockReader).load()
  }
}
