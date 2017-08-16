# Copyright 2017 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#            http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse
import tensorflow as tf
import task

ARTIFACT_DIR = './test/artifacts/'
DATA_DIR = './test/'
DATA_FILE = 'data.tfrecords'


class TaskTests(tf.test.TestCase):
  def test_get_feature_columns(self):
    feature_columns = task.get_feature_columns(ARTIFACT_DIR)
    self.assertEqual(len(feature_columns),
                     len(task.INTEGER_FEATURES) + len(task.CATEGORICAL_FEATURES)
                     )

  def test_generate_labelled_input_fn(self):
    batch_size = 2
    data_glob = '{}{}'.format(DATA_DIR, DATA_FILE)
    labelled_input_fn = task.generate_labelled_input_fn(2, data_glob)
    features, labels = labelled_input_fn()

    with tf.Session() as sess:
      coord = tf.train.Coordinator()
      threads = tf.train.start_queue_runners(coord=coord)
      result = sess.run({'features': features,
                         'labels': labels})
      coord.request_stop()
      coord.join(threads)

    features_out = result['features']
    for key in features_out:
      self.assertEqual(features_out[key].shape, (batch_size,1))

    labels_out = result['labels']
    self.assertEqual(labels_out.shape, (batch_size,1))

  def test_end_to_end(self):
    job_dir = tf.test.get_temp_dir()

    args = argparse.Namespace(
        job_dir=job_dir,
        train_dir=DATA_DIR,
        eval_dir=DATA_DIR,
        artifact_dir=ARTIFACT_DIR,
        batch_size=2,
        train_steps=10,
        eval_steps=1,
        learning_rate=0.5,
        min_eval_frequency=0
    )

    config = tf.contrib.learn.RunConfig()
    params = tf.contrib.training.HParams(learning_rate=args.learning_rate)

    estimator = task.generate_estimator(args.artifact_dir,
                                        args.job_dir,
                                        params,
                                        config)

    train_glob = '{}*.tfrecords'.format(args.train_dir)
    eval_glob = '{}*.tfrecords'.format(args.eval_dir)

    experiment = task.generate_experiment(estimator,
                                          args.batch_size,
                                          train_glob,
                                          eval_glob,
                                          args.train_steps,
                                          args.eval_steps,
                                          args.min_eval_frequency)

    experiment.train_and_evaluate()

if __name__ == '__main__':
  tf.test.main()

