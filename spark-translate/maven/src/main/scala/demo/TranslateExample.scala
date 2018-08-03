/*
 Copyright Google Inc. 2018
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 http://www.apache.org/licenses/LICENSE-2.0
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/

package demo

import org.apache.spark.sql.SparkSession

import com.google.cloud.translate.Translate
import com.google.cloud.translate.Translate.TranslateOption
import com.google.cloud.translate.TranslateOptions
import com.google.cloud.translate.Translation

object TranslateExample {

  val translateService = TranslateOptions.getDefaultInstance().getService()

  def translate(word: String, language: String): String = {
    val translation = translateService.translate(
	    word,
	    TranslateOption.sourceLanguage("en"),
	    TranslateOption.targetLanguage(language))
	  return translation.getTranslatedText()
  }

  def main(args: Array[String]): Unit = {
  	if (args.length != 4) {
      System.err.println(
        """
          | Usage: TranslateExample <language> <bucket> <input> <output>
          |
          | <language>: Target language code for the translation (e.g. "fr" for French). See the list of supported languages: https://cloud.google.com/translate/docs/languages
          | <bucket>: Bucket's URI
          | <input>: Name of the input text file
          | <output>: Name of the output folder
          |
        """.stripMargin)
      System.exit(1)
    }

    val Seq(language, bucket, input, output) = args.toSeq

    val spark = SparkSession.builder.appName("Simple Application").getOrCreate()

    // Import Dataset encoders
    import spark.implicits._

    val words = spark.read.textFile(bucket + "/" + input)

    val translated = words.map(word => translate(word, language))

    translated.write.mode("overwrite").text(bucket + "/" + output)
  }
}