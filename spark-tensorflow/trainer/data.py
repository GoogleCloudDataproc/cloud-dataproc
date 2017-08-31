# Copyright 2017 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#            http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import multiprocessing
import tensorflow as tf

TSV = 'tsv'
TFRECORDS = 'tfrecords'
SERVING = 'serving'
FILE_FORMATS = [TSV, TFRECORDS]

INTEGER_FEATURES = ['integer-feature-{}'.format(i)
                    for i in range(1, 14)]

CATEGORICAL_FEATURES = ['categorical-feature-{}'.format(i)
                        for i in range(1, 27)]

LABEL = 'clicked'


def generate_labelled_input_fn(fmt, batch_size, data_glob, artifact_dir):
  """
  Args:
    fmt: Format of files from which data is being read
    batch_size: A positive integer specifying how large we would like each batch
    of training or evaluation to be
    data_glob: A glob which matches the tfrecords files containing labelled
    input data
    artifact_dir: Optional path to either local directory or GCS bucket
    containing preprocessing artifacts

  Returns:
    An input_fn which returns labelled data for use with tf.estimator.Estimator
  """
  features = {}

  for f in INTEGER_FEATURES + [LABEL]:
    features[f] = tf.FixedLenFeature([1], dtype=tf.float32)

  for f in CATEGORICAL_FEATURES:
    features[f] = tf.FixedLenFeature([1], dtype=tf.string)

  def tfrecords_input_fn():
    features_batch = tf.contrib.learn.read_batch_features(
        file_pattern=data_glob,
        batch_size=batch_size,
        features=features,
        reader=tf.TFRecordReader,
        queue_capacity=20*batch_size,
        feature_queue_capacity=10*batch_size
    )

    label_batch = features_batch.pop(LABEL)

    return features_batch, label_batch

  def tsv_input_fn():
    filenames = tf.gfile.Glob(data_glob)
    filename_queue = tf.train.string_input_producer(
      filenames,
      shuffle=True)
    reader = tf.TextLineReader()

    integer_feature_defaults = [
      [get_integer_artifacts(feature, artifact_dir)]
      for feature in INTEGER_FEATURES]

    categorical_feature_defaults = [
      ['null']
      for feature in CATEGORICAL_FEATURES]

    feature_defaults = ([[]] +
      integer_feature_defaults +
      categorical_feature_defaults)

    _, rows = reader.read_up_to(filename_queue, num_records=batch_size)

    expanded_rows = tf.expand_dims(rows, axis=-1)

    columns = tf.decode_csv(expanded_rows,
      record_defaults=feature_defaults,
      field_delim='\t')

    features = dict(zip(
      [LABEL] + INTEGER_FEATURES + CATEGORICAL_FEATURES,
      columns)
    )
    
    features_batch = tf.train.shuffle_batch(
      features,
      batch_size,
      min_after_dequeue=2*batch_size+1,
      capacity=batch_size*10,
      num_threads=multiprocessing.cpu_count(),
      enqueue_many=True,
      allow_smaller_final_batch=True)

    label_batch = features_batch.pop(LABEL)

    return features_batch, label_batch

  format_input_fn_map = {
    TSV: tsv_input_fn,
    TFRECORDS: tfrecords_input_fn
  }

  return format_input_fn_map[fmt]


def get_feature_columns(fmt, artifact_dir):
  """
  Args:
    fmt: Format of files from which data is being read
    artifact_dir: Path to either local directory or GCS bucket containing
    preprocessing artifacts

    This directory should contain one subdirectory
    for each of the integer features `integer-feature-$i` for i in {1..13}
    with each subdirectory having a `mean.txt` file defining the mean of that
    feature in the training data (conditioned on the feature being filled).

    It should also contain one subdirectory for each of the categorical
    features `categorical-feature-$i` for i in {1..26} with each subdirectory
    having two files - `count.txt` and `index.txt`. `index.txt` should contain
    the vocabulary items in decreasing order of frequency of appearance in the
    training data. `count.txt` should contain the number of lines in
    `index.txt`.

  Returns:
    None
  """

  integer_columns = [integer_column(fmt, feature, artifact_dir)
                     for feature in INTEGER_FEATURES]

  categorical_columns = [categorical_column(fmt, feature, artifact_dir) for
                         feature in CATEGORICAL_FEATURES]

  input_columns = integer_columns + categorical_columns

  return input_columns


def integer_column(fmt, feature, artifact_dir):
  """
  Args:
    fmt: Format of files from which data is being read
    feature: Name of integer feature
    artifact_dir: Path to directory in which mean for that feature is stored

  Returns:
    A feature column representing the given feature
  """
  if fmt == TFRECORDS:
    int_column = tf.feature_column.numeric_column(key=feature)
  else:
    mean = get_integer_artifacts(feature, artifact_dir)
    int_column = tf.feature_column.numeric_column(
      key=feature,
      default_value=mean)

  return int_column


def get_integer_artifacts(feature, artifact_dir):
  with tf.gfile.Open(
      '{}{}/mean.txt'.format(artifact_dir, feature),
      'r') as mean_file:
    mean = float(mean_file.read())
  return mean


def categorical_column(fmt, feature, artifact_dir):
  """
  Args:
    fmt: Format of files from which data is being read
    feature: Name of categorical feature
    artifact_dir: Path to directory in which mean for that feature is stored

  Returns:
    A feature column representing the given feature
  """
  if fmt == TFRECORDS:
    cat_column = tf.feature_column.numeric_column(key=feature)
  else:
    count, vocabulary_file = get_categorical_artifacts(feature, artifact_dir)
    cat_column = tf.feature_column.categorical_column_with_vocabulary_file(
        key=feature,
        vocabulary_file=vocabulary_file,
        vocabulary_size=count,
        num_oov_buckets=1)

  return cat_column


def get_categorical_artifacts(feature, artifact_dir):
  with tf.gfile.Open(
      '{}{}/count.txt'.format(artifact_dir, feature),
      'r') as count_file:
    count = int(count_file.read())

  vocabulary_file = '{}{}/index.txt'.format(artifact_dir, feature)
  return (count, vocabulary_file)
