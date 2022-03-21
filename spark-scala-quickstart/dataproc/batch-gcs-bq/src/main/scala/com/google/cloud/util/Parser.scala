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

import com.google.cloud.BatchExample.appName

object Parser {

  // Parse arguments
  case class MainArguments(inputPath: String = "",
                           outputTable: String = "",
                           writeMode: String = "",
                           temporaryGcsBucketPath: String = ""
                      )

  val mainParser = new scopt.OptionParser[MainArguments]("") {
    opt[String]('i', "inputPath").required().valueName("").action((v, args) => args.copy(inputPath = v))
    opt[String]('o', "outputTable").required().valueName("").action((v, args) => args.copy(outputTable = v))
    opt[String]('m', "writeMode").required().valueName("").action((v, args) => args.copy(writeMode = v))
    opt[String]('t', "temporaryGcsBucketPath").valueName("").action((v, args) => args.copy(temporaryGcsBucketPath = v))
  }
}
