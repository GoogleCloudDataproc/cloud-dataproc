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
package com.google.cloud.util

import org.scalatest.funsuite.AnyFunSuite

class ParserTest extends AnyFunSuite  {

  test("Should parse args") {

    val parser = Parser.mainParser
    val expected = new Parser.MainArguments("brokers","topic", "/any", "10 seconds", "10 seconds", "10 seconds", "/any")

    val args = Seq("--brokers=brokers","--topic=topic", "--checkpointPath=/any", "--watermark=10 seconds", "--windowDuration=10 seconds", "--triggerProcTime=10 seconds", "--outputPath=/any")

    assert(parser.parse(args, Parser.MainArguments()).contains(expected))
  }

}