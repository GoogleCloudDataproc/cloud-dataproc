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

object Parser {

  // Parse arguments
  case class MainArguments( brokers: String = "",
                            topic: String = "",
                            checkpointPath: String = "",
                            watermark: String = "",
                            windowDuration: String = "",
                            triggerProcTime: String = "",
                            outputPath: String = ""
                          )

  val mainParser = new scopt.OptionParser[MainArguments]("") {
    opt[String]('b', "brokers").required().valueName("").action((v, args) => args.copy(brokers = v))
    opt[String]('t', "topic").required().valueName("").action((v, args) => args.copy(topic = v))
    opt[String]('c', "checkpointPath").required().valueName("").action((v, args) => args.copy(checkpointPath = v))
    opt[String]('m', "watermark").required().valueName("").action((v, args) => args.copy(watermark = v))
    opt[String]('w', "windowDuration").required().valueName("").action((v, args) => args.copy(windowDuration = v))
    opt[String]('r', "triggerProcTime").required().valueName("").action((v, args) => args.copy(triggerProcTime = v))
    opt[String]('o', "outputPath").required().valueName("").action((v, args) => args.copy(outputPath = v))
  }
}
