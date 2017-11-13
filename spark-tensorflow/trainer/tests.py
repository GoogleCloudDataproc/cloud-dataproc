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

"""Tests."""

import argparse
import data
import os
import task
import tensorflow as tf

THIS_DIR = os.path.dirname(__file__)
ARTIFACT_DIR = os.path.join(THIS_DIR, 'test/artifacts/')
DATA_DIR = os.path.join(THIS_DIR, 'test/')


class SampleTests(tf.test.TestCase):
    """All tests for this sample.

    Test data is present in the 'tests/' directory.
    """

    def test_get_feature_columns(self):
        feature_columns = data.get_feature_columns(
            data.TSV,
            ARTIFACT_DIR)
        self.assertEqual(len(feature_columns),
                         len(data.INTEGER_FEATURES) +
                         len(data.CATEGORICAL_FEATURES)
                         )

    def test_generate_labelled_input_fn_tsv(self):
        tsv_data_file = 'train.tsv'
        batch_size = 2
        data_glob = '{}{}'.format(DATA_DIR, tsv_data_file)
        labelled_input_fn = data.generate_labelled_input_fn(
            data.TSV,
            2,
            data_glob,
            ARTIFACT_DIR)
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
            self.assertEqual(features_out[key].shape, (batch_size, 1))

        labels_out = result['labels']
        self.assertEqual(labels_out.shape, (batch_size, 1))

    def test_end_to_end_tsv(self):
        job_dir = tf.test.get_temp_dir()

        args = argparse.Namespace(
            job_dir=job_dir,
            data_format=data.TSV,
            train_dir=DATA_DIR,
            eval_dir=DATA_DIR,
            artifact_dir=ARTIFACT_DIR,
            batch_size=2,
            train_steps=10,
            eval_steps=1,
            learning_rate=0.5,
            min_eval_frequency=0
        )

        task.dispatch(args)


if __name__ == '__main__':
    tf.test.main()
