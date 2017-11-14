# Copyright 2017 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse
import csv
import tempfile
import StringIO


from google.cloud import storage


integer_features = ['integer-feature-{}'.format(i) for i in range(1, 14)]
categorical_features = ['categorical-feature-{}'.format(i)
                        for i in range(1, 27)]


def preprocess_integer_dirs(bucket, artifact_dir):
    client = storage.Client()
    bucket = client.get_bucket(bucket)
    blobs = list(bucket.list_blobs())

    for ifeature in integer_features:
        ifeature = artifact_dir + '/' + ifeature
        files = filter(lambda b: b.name.startswith(ifeature), blobs)
        csv = filter(lambda b: 'csv' in b.name, files)[0]
        value = csv.download_as_string()
        path = csv.name[:csv.name.rfind('/')]
        new_name = path + '/mean.txt'
        print('Renaming {} to {}'.format(csv.name, new_name))
        new_blob = bucket.blob(new_name)
        new_blob.upload_from_string(value)


def preprocess_categorical_dirs(bucket, artifact_dir):
    client = storage.Client()
    bucket = client.get_bucket(bucket)
    blobs = list(bucket.list_blobs())

    for cfeature in categorical_features:
        new_file, filename = tempfile.mkstemp()
        cfeature = artifact_dir + '/' + cfeature
        files = filter(lambda b: b.name.startswith(cfeature), blobs)
        csv_file = filter(lambda b: 'csv' in b.name, files)[0]
        csv_file.download_to_filename(filename)

        path = csv_file.name[:csv_file.name.rfind('/')]

        with open(filename, 'r') as part_file:
            csvreader = csv.reader(part_file)
            features = [row[0] for row in csvreader]

        output = StringIO.StringIO()
        for feature in features:
            if not feature:
                feature = 'null'
            output.write('{}\n'.format(feature))

        index_name = path + '/index.txt'
        index_blob = bucket.blob(index_name)
        index_blob.upload_from_string(output.getvalue())

        output = StringIO.StringIO()
        output.write('{}\n'.format(len(features)))
        count_name = path + '/count.txt'
        count_blob = bucket.blob(count_name)
        count_blob.upload_from_string(output.getvalue())

        print('Wrote feature in {}'.format(cfeature))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)

    parser.add_argument('bucket')
    parser.add_argument('artifact_dir')

    args = parser.parse_args()
    preprocess_integer_dirs(args.bucket, args.artifact_dir)
    preprocess_categorical_dirs(args.bucket, args.artifact_dir)
