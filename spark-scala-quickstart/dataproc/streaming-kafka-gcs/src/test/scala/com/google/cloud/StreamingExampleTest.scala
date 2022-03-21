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
package com.google.cloud

import com.google.cloud.read.KafkaConsumer
import com.google.cloud.test_utils.TestUtils.getInputDF
import com.google.cloud.util.Parser
import com.google.cloud.write.WriteStorage
import org.apache.spark.sql.DataFrame
import org.mockito.ArgumentMatchers._
import org.mockito.MockitoSugar
import org.scalatest.funsuite.AnyFunSuite

class StreamingExampleTest extends AnyFunSuite with MockitoSugar {

  test("Should run ETL job") {

    val mockKafkaConsumer = mock[KafkaConsumer]
    val mockWriteStorage = mock[WriteStorage]

    when(mockKafkaConsumer.consume(anyString(), anyString())).thenReturn(getInputDF)
    doNothing.when(mockWriteStorage).write(any[DataFrame], anyString(), anyString(), anyString())

    StreamingExample.runETL(Parser.MainArguments("brokers","topic", "/any", "10 seconds", "10 seconds", "10 seconds", "/any"), mockKafkaConsumer, mockWriteStorage)
  }

}