#!/bin/bash

SPARK_TF_PATH=$(dirname "$(readlink -f $0)")
cd "$SPARK_TF_PATH"
python -m trainer.tests $@
