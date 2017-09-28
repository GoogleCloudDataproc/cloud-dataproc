#!/usr/bin/env bash
spark-submit --master local --driver-memory 12g --executor-memory 12g --class com.google.cloud.ml.samples.criteo.CriteoPreprocessingApplication --jars lib/spark-tensorflow-connector-assembly-1.0.0.jar,lib/scopt_2.11-3.6.0.jar target/scala-2.11/criteo-prepare_2.11-1.0.jar --base $BASE --in $1 --out $2 -m $3 -x $4 ${@:5}
