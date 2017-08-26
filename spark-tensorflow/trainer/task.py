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

import argparse
import tensorflow as tf

import data
import model


def generate_experiment(estimator,
                        data_format,
                        artifact_dir,
                        batch_size,
                        train_glob,
                        eval_glob,
                        train_steps,
                        eval_steps,
                        min_eval_frequency):
  """
  Args:
    estimator: tf.estimator.Estimator which will perform the classification
    data_format: File format for training and evaluation data
    artifact_dir: Directory containing preprocessing artifacts
    train_glob: Glob pattern matching the training data
    eval_glob: Glob pattern matching evaluation data
    train_steps: Number of training steps to perform
    eval_steps: Number of evaluation steps to perform
    min_eval_frequency: Number of training steps between evaluation steps

  Returns:
    A tf.contrib.learn.Experiment which defines the training job. To train, call
    its train_and_evaluate method. This automatically exports a saved model
    for TensorFlow Serving into the export subdirectory of the estimator's model
    directory.
  """
  train_input_fn = data.generate_labelled_input_fn(
    data_format,
    batch_size,
    train_glob,
    artifact_dir)
  eval_input_fn = data.generate_labelled_input_fn(
    data_format,
    batch_size,
    eval_glob,
    artifact_dir)

  export_fn = generate_export_fn()
  export_strategy = tf.contrib.learn.ExportStrategy('default', export_fn)

  return tf.contrib.learn.Experiment(
      estimator,
      train_input_fn=train_input_fn,
      eval_input_fn=eval_input_fn,
      train_steps=train_steps,
      eval_steps=eval_steps,
      min_eval_frequency=min_eval_frequency,
      export_strategies=export_strategy
  )


def generate_export_fn():
  """
  Returns:
    An export_fn for use with tf.contrib.learn.Experiment
  """
  export = tf.estimator.export

  features = {}

  features['id'] = tf.placeholder(dtype=tf.string, shape=[None])

  for feature in data.INTEGER_FEATURES:
    features[feature] = tf.placeholder(dtype=tf.float32, shape=[None, 1])

  for feature in data.CATEGORICAL_FEATURES:
    features[feature] = tf.placeholder(dtype=tf.string, shape=[None, 1])

  serving_input_receiver_fn = export.build_raw_serving_input_receiver_fn(
      features=features
  )

  def export_fn(estimator, export_path, checkpoint_path):
    """
    Wraps the estimators export_savedmodel method to make it compatible with
    tf.contrib.learn.Experiment.

    Args:
      estimator: A tf.estimator.Estimator
      export_path: Path to which saved model should be exported
      checkpoint_path: Optional checkpoint from which the export is taking place

    Returns:
      Path to which model was exported
    """
    return estimator.export_savedmodel(
        export_path,
        serving_input_receiver_fn,
        checkpoint_path=checkpoint_path
    )

  return export_fn


def dispatch(args):
  train_glob = '{}*.{}'.format(args.train_dir, args.data_format)
  eval_glob = '{}*.{}'.format(args.eval_dir, args.data_format)

  labelled_feature_cols = data.get_feature_columns(
    args.data_format,
    args.artifact_dir)

  prediction_feature_cols = data.get_feature_columns(
    data.SERVING,
    args.artifact_dir)

  mode_feature_cols_map = {
    model.MODES.TRAIN: labelled_feature_cols,
    model.MODES.EVAL: labelled_feature_cols,
    model.MODES.PREDICT: prediction_feature_cols
  }

  config = tf.contrib.learn.RunConfig()
  params = tf.contrib.training.HParams(learning_rate=args.learning_rate)

  estimator = model.generate_estimator(
    mode_feature_cols_map,
    args.artifact_dir,
    args.job_dir,
    params,
    config)

  experiment = generate_experiment(estimator,
    args.data_format,
    args.artifact_dir,
    args.batch_size,
    train_glob,
    eval_glob,
    args.train_steps,
    args.eval_steps,
    args.min_eval_frequency)

  experiment.train_and_evaluate()


if __name__ == '__main__':
  parser = argparse.ArgumentParser(
      'Spark Preprocessing + TensorFlow estimator + Criteo data'
  )
  parser.add_argument(
      '--job-dir',
      required=True,
      help='The directory in which trained models should (and may already ' +
      'be) saved (can be a GCS path)'
  )
  parser.add_argument(
      '--data-format',
      default=data.TSV,
      choices=data.FILE_FORMATS,
      help='Format of data files. (Note: Data files must be of same format.')
  parser.add_argument(
      '--train-dir',
      required=True,
      help='Directory containing the training data')
  parser.add_argument(
      '--eval-dir',
      required=True,
      help='Directory containing the evaluation data'
  )
  parser.add_argument(
      '--artifact-dir',
      type=str,
      required=True,
      help='Directory containing preprocessing artifacts'
  )
  parser.add_argument(
      '--batch-size',
      type=int,
      default=10000,
      help='The size of the batches in which the criteo data should be ' +
      'processed'
  )
  parser.add_argument(
      '--train-steps',
      type=int,
      help='The number of batches that we should train on (if unspecified, ' +
      'trains forever)'
  )
  parser.add_argument(
      '--eval-steps',
      type=int,
      default=1,
      help='The number of evaluation batches that should be used in evaluation'
  )
  parser.add_argument(
      '--learning-rate',
      type=float,
      default=0.01,
      help='The learning rate used in the Gradient Descent optimization for ' +
      'logistic regressor.'
  )
  parser.add_argument(
      '--min-eval-frequency',
      type=int,
      default=0,
      help='The minimum number of training steps between evaluations. If 0, ' +
      'evaluation takes place only after training. Default is 0.'
  )

  args = parser.parse_args()

  dispatch(args)
