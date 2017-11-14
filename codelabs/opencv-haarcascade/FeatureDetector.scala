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

package com.google.spark.feature_detector


import java.io.File
import org.apache.hadoop.conf.Configuration
import org.apache.hadoop.fs.Path
import org.apache.hadoop.io.IOUtils
import org.apache.spark.SparkConf
import org.apache.spark.SparkContext
import org.apache.spark.SparkFiles
import org.bytedeco.javacpp.opencv_core.Mat
import org.bytedeco.javacpp.opencv_core.RectVector
import org.bytedeco.javacpp.opencv_core.Scalar
import org.bytedeco.javacpp.opencv_imgcodecs.imread
import org.bytedeco.javacpp.opencv_imgcodecs.imwrite
import org.bytedeco.javacpp.opencv_imgproc.rectangle
import org.bytedeco.javacpp.opencv_objdetect.CascadeClassifier


object FeatureDetector {


  def main (args: Array[String]){
    val conf = new SparkConf()
    val sc = new SparkContext(conf)

    val timestamp1 = System.currentTimeMillis()


    // The 1st argument is the path of the classifier.
    // The 2nd argument is the directory where the input images are located.
    // The optional 3rd argument is the directory where the output images will be written.
    if (args.length < 2 || args.length > 3) {
      println("usage: <classifier-path> <input-directory> [output-directory]")
      System.exit(-1)
    }
    val classifierPath = args(0)
    val inputDirName = args(1)
    val outputDirName = if (args.length == 2) inputDirName else args(2)


    val classifier = downloadToCluster(classifierPath, sc)


    val inputDir = new Path(inputDirName)
    val fs = inputDir.getFileSystem(new Configuration())
    val files = fs.listStatus(inputDir)
    val filePaths = files.map(_.getPath().toString())
    println("Number of files found: " + filePaths.length);


    sc.parallelize(filePaths).foreach({
      processImage(_, classifier.getName(), outputDirName)
    })


    val timestamp2 = System.currentTimeMillis()


    println("\n\n")
    println("The output files can be found at " + outputDirName)
    println("Total time: " + (timestamp2-timestamp1) + " milliseconds.")
    println("\n\n")
  }


  def processImage(inPath: String, classifier: String, outputDir: String): String = {
    val classifierName = SparkFiles.get(classifier)

    println("Processing image file: " + inPath);

    // Download the input file to the worker.
    val suffix = inPath.lastIndexOf(".")
    val localIn = File.createTempFile("pic_",
        inPath.substring(suffix),
        new File("/tmp/"))
    copyFile(inPath, "file://" + localIn.getPath())


    val inImg = imread(localIn.getPath())
    val detector = new CascadeClassifier(classifierName)
    val outImg = detectFeatures(inImg, detector)


    // Write the output image to a temporary file.
    val localOut = File.createTempFile("out_",
        inPath.substring(suffix),
        new File("/tmp/"))
    imwrite(localOut.getPath(), outImg)


    // Copy the file to the output directory.
    val filename = inPath.substring(inPath.lastIndexOf("/") + 1)
    val extension = filename.substring(filename.lastIndexOf("."))
    val name = filename.substring(0, filename.lastIndexOf("."))
    val outPath = outputDir + name +"_output" + extension
    copyFile("file://" + localOut.getPath(), outPath)
    return outPath
  }


  // Outlines the detected features in a given Mat.
  def detectFeatures(img: Mat, detector: CascadeClassifier): Mat = {
    val features = new RectVector()
    detector.detectMultiScale(img, features)
    val numFeatures = features.size().toInt
    val outlined = img.clone()


    // Draws the rectangles on the detected features.
    val green = new Scalar(0, 255, 0, 0)
    for (f <- 0 until numFeatures) {
      val currentFeature = features.get(f)
      rectangle(outlined, currentFeature, green)
    }
    return outlined
  }


  // Copies file to and from given locations.
  def copyFile(from: String, to: String) {
    val conf = new Configuration()
    val fromPath = new Path(from)
    val toPath = new Path(to)
    val is = fromPath.getFileSystem(conf).open(fromPath)
    val os = toPath.getFileSystem(conf).create(toPath)
    IOUtils.copyBytes(is, os, conf)
    is.close()
    os.close()
  }


  // Downloads the file to every node in the cluster.
  def downloadToCluster(path: String, sc: SparkContext): File = {
    val suffix = path.substring(path.lastIndexOf("."))
    val file = File.createTempFile("file_", suffix, new File("/tmp/"))
    copyFile(path, "file://" + file.getPath())
    sc.addFile("file://" + file.getPath())
    return file
  }
}
