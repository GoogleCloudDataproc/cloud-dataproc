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
  case class MainArguments( rawCsv: String = "",
                            inputParquet: String = "",
                            outputParquet: String = "",
                            inputTable: String = "",
                            outputTable: String = "",
                            temporaryGcsBucketPath: String = "" )

  val mainParser = new scopt.OptionParser[MainArguments]("") {
    opt[String]('r', "rawCsv").required().valueName("").action((v, args) => args.copy(rawCsv = v))
    opt[String]('i', "inputParquet").required().valueName("").action((v, args) => args.copy(inputParquet = v))
    opt[String]('b', "outputParquet").required().valueName("").action((v, args) => args.copy(outputParquet = v))
    opt[String]('b', "inputTable").required().valueName("").action((v, args) => args.copy(inputTable = v))
    opt[String]('q', "outputTable").required().valueName("").action((v, args) => args.copy(outputTable = v))
    opt[String]('t', "temporaryGcsBucketPath").required().valueName("").action((v, args) => args.copy(temporaryGcsBucketPath = v))
  }
}
