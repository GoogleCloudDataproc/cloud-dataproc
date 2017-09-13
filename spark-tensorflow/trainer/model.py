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

"""Model definition."""

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import tensorflow as tf


MODES = tf.estimator.ModeKeys


def generate_estimator(
        mode_feature_cols_map,
        params,
        config):
    """Creates a tf.estimator.Estimator for the Criteo classification task.

    Args:
      mode_feature_cols_map: Dictionary mapping modes to lists of
      tf.feature_columns describing the features to expect in each mode
      params: Hyperparameter object (assumed to be an instance of
      tf.contrib.training.HParams
      config: An instance of tf.contrib.learn.RunConfig

    Returns:
      A tf.estimator.Estimator representing the logistic classifier we will use
    """
    model_fn = generate_model_fn(mode_feature_cols_map)

    return tf.estimator.Estimator(
        model_fn,
        model_dir=config.model_dir,
        params=params,
        config=config
    )


def generate_model_fn(mode_feature_cols_map):
    """Creates a model_fn to inject into our custom estimator.

    Args:
      mode_feature_cols_map: Dictionary mapping modes to lists of
      tf.feature_columns describing the features to expect in each mode

    Returns:
      A model_fn for tf.estimator.Estimator. Has the following signature:
      Args:
        features: A dictionary of strings to tensors describing the model
        features
        labels: Either None or a tensor representing the labels for a given
        batch of training or evaluation data
        mode: A member of tf.estimator.ModeKeys -- TRAIN, EVAL, or PREDICT
        params: tf.contrib.training.HParams object or None
        config: tf.contrib.learn.RunConfig object or None

      Returns:
        tf.estimator.EstimatorSpec object
    """
    def model_fn(features, labels, mode, params=None, config=None):
        if params is None:
            params = tf.contrib.training.HParams(learning_rate=0.01)

        # Extract the id tensor from the input features if it exists in the
        # feature_columns
        id_tensor = None
        if 'id' in features:
            id_tensor = features.pop('id')

        # Feature columns for given mode
        feature_cols = mode_feature_cols_map[mode]

        # Tensor of logits formed from input features
        logits = tf.feature_column.linear_model(features, feature_cols)

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

        eval_metric_ops = None

        if mode == MODES.EVAL:
            eval_metric_ops = {
                'accuracy': tf.metrics.accuracy(labels, logistic)}

        # Define serving signatures
        prediction_output = tf.estimator.export.PredictOutput(
            classifier_output)

        export_outputs = {
            tf.saved_model.signature_constants.DEFAULT_SERVING_SIGNATURE_DEF_KEY:
            prediction_output
        }

        return tf.estimator.EstimatorSpec(
            mode=mode,
            predictions=classifier_output,
            loss=loss,
            train_op=train_op,
            eval_metric_ops=eval_metric_ops,
            export_outputs=export_outputs
        )

    return model_fn
