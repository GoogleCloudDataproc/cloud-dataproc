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
import copy
import tensorflow as tf

MODES = tf.estimator.ModeKeys

INTEGER_FEATURES = ['integer-feature-{}'.format(i)
                    for i in range(1, 14)]

CATEGORICAL_FEATURES = ['categorical-feature-{}'.format(i)
                        for i in range(1, 27)]


def get_feature_columns(artifact_dir):
  """
  Args:
    artifact_dir: Path to either local directory or GCS bucket containing
    preprocessing artifacts.

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

  integer_columns = [integer_column(feature, artifact_dir)
                     for feature in INTEGER_FEATURES]

  categorical_columns = [categorical_column(feature, artifact_dir) for
                         feature in CATEGORICAL_FEATURES]

  input_columns = integer_columns + categorical_columns

  return input_columns


def integer_column(feature, artifact_dir):
  """
  Args:
    feature: Name of integer feature
    artifact_dir: Path to directory in which mean for that feature is stored

  Returns:
    A feature column representing the given feature
  """
  mean = get_integer_artifacts(feature, artifact_dir)
  return tf.feature_column.numeric_column(key=feature, default_value=mean)


def get_integer_artifacts(feature, artifact_dir):
  with tf.gfile.Open(
      '{}{}/mean.txt'.format(artifact_dir, feature),
      'r') as mean_file:
    mean = float(mean_file.read())
  return mean


def categorical_column(feature, artifact_dir):
  count, vocabulary_file = get_categorical_artifacts(feature, artifact_dir)
  cat_column = tf.feature_column.categorical_column_with_vocabulary_file(
      key=feature,
      vocabulary_file=vocabulary_file,
      vocabulary_size=count)
#  return tf.feature_column.indicator_column(cat_column)
  return cat_column


def get_categorical_artifacts(feature, artifact_dir):
  with tf.gfile.Open(
      '{}{}/count.txt'.format(artifact_dir, feature),
      'r') as count_file:
    count = int(count_file.read())

  vocabulary_file = '{}{}/index.txt'.format(artifact_dir, feature)
  return (count, vocabulary_file)


def generate_labelled_input_fn(batch_size, data_glob):
  """
  Args:
    batch_size: A positive integer specifying how large we would like each batch
    of training or evaluation to be
    data_glob: A glob which matches the tfrecords files containing labelled
    input data

  Returns:
    An input_fn which returns labelled data for use with tf.estimator.Estimator
  """
  features = {}

  for f in INTEGER_FEATURES + ['clicked']:
    features[f] = tf.FixedLenFeature([1], dtype=tf.float32)

  for f in CATEGORICAL_FEATURES:
    features[f] = tf.FixedLenFeature([1], dtype=tf.string)

  def preprocessed_input_fn():
    features_batch = tf.contrib.learn.read_batch_features(
        file_pattern=data_glob,
        batch_size=batch_size,
        features=features,
        reader=tf.TFRecordReader,
        queue_capacity=20*batch_size,
        feature_queue_capacity=10*batch_size
    )

    label_batch = features_batch.pop('clicked')

    return features_batch, label_batch

  return preprocessed_input_fn


def generate_model_fn(artifact_dir):
  """
  Creates a model_fn to inject into our custom estimator. Trains with simple
  gradient descent.

  Args:
    artifact_dir: Path to either local directory or GCS bucket containing
    preprocessing artifacts.

  Returns:
    A model_fn for tf.estimator.Estimator. Has the following signature:
    Args:
      features: A dictionary of strings to tensors describing the model features
      labels: Either None or a tensor representing the labels for a given batch
      of training or evaluation data
      mode: A member of tf.estimator.ModeKeys -- TRAIN, EVAL, or PREDICT
      params: tf.contrib.training.HParams object or None
      config: tf.contrib.learn.RunConfig object or None

    Returns:
      tf.estimator.EstimatorSpec object
  """
  def model_fn(features, labels, mode, params=None, config=None):
    input_columns = get_feature_columns(artifact_dir)

    if params is None:
      params = tf.contrib.training.HParams(learning_rate=0.01)

    # Extract the id tensor from the input features if it exists in the
    # feature_columns
    id_tensor = None
    if 'id' in features:
      id_tensor = features.pop('id')

    # Tensor of logits formed from input features
    logits = tf.feature_column.linear_model(features, input_columns)

    # Apply the logistic function to the logits defined above
    # This is our classifier
    logistic = tf.sigmoid(logits, name='logistic')

    classifier_output = {
        'clicked': logistic
    }

    if id_tensor is not None:
      classifier_output['id'] = tf.identity(id_tensor)

    loss = None
    train_op = None

    if mode in (MODES.TRAIN, MODES.EVAL):
      loss = tf.reduce_mean(
          tf.nn.sigmoid_cross_entropy_with_logits(
              logits=logits, labels=labels, name='loss')
      )

    if mode == MODES.TRAIN:
      global_step = tf.train.get_or_create_global_step()
      train_op = tf.train.GradientDescentOptimizer(
          learning_rate=params.learning_rate
      ).minimize(loss, global_step=global_step)

    # Define serving signatures
    prediction_output = tf.estimator.export.PredictOutput(classifier_output)

    export_outputs = {
        tf.saved_model.signature_constants.DEFAULT_SERVING_SIGNATURE_DEF_KEY:
        prediction_output
    }

    return tf.estimator.EstimatorSpec(
        mode=mode,
        predictions=classifier_output,
        loss=loss,
        train_op=train_op,
        export_outputs=export_outputs
    )

  return model_fn


def generate_estimator(artifact_dir, model_dir, params, config):
  """
  Args:
    artifact_dir: Directory containing preprocessing artifacts for each of the
    input features in our logistic classifier
    model_dir: Directory in which to store model checkpoints
    params: Hyperparameter object (assumed to be an instance of
    tf.contrib.training.HParams
    config: An instance of tf.contrib.learn.RunConfig

  Returns:
    A tf.estimator.Estimator representing the logistic classifier we will use
  """
  model_fn = generate_model_fn(artifact_dir)
 
  return tf.estimator.Estimator(
      model_fn,
      model_dir=model_dir,
      params=params,
      config=config
  )


def generate_export_fn():
  """
  Returns:
    An export_fn for use with tf.contrib.learn.Experiment
  """
  export = tf.estimator.export

  features = {}

  features['id'] = tf.placeholder(dtype=tf.string, shape=[None])

  for feature in INTEGER_FEATURES:
    features[feature] = tf.placeholder(dtype=tf.float32, shape=[None, 1])

  for feature in CATEGORICAL_FEATURES:
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


def generate_experiment(estimator,
                        batch_size,
                        train_glob,
                        eval_glob,
                        train_steps,
                        eval_steps,
                        min_eval_frequency):
  """
  Args:
    estimator: tf.estimator.Estimator which will perform the classification
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
  train_input_fn = generate_labelled_input_fn(batch_size, train_glob)
  eval_input_fn = generate_labelled_input_fn(batch_size, eval_glob)

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

  train_glob = '{}*.tfrecords'.format(args.train_dir)
  eval_glob = '{}*.tfrecords'.format(args.eval_dir)

  config = tf.contrib.learn.RunConfig()
  params = tf.contrib.training.HParams(learning_rate=args.learning_rate)

  estimator = generate_estimator(args.artifact_dir,
                                 args.job_dir,
                                 params,
                                 config)

  experiment = generate_experiment(estimator,
                                   args.batch_size,
                                   train_glob,
                                   eval_glob,
                                   args.train_steps,
                                   args.eval_steps,
                                   args.min_eval_frequency)

  experiment.train_and_evaluate()
