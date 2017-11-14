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

import argparse
import os
import shutil
import csv



# TODO: would be better to figure out how to have Scala output it correctly

def preprocess_integer_dirs(artifact_dir):
    dirs = os.listdir(artifact_dir)
    integer_dirs = filter(lambda dir: dir.startswith('integer-feature'), dirs)
    assert len(integer_dirs) == 13, 'Expected 13 integer feature directories'
    for integer_dir in integer_dirs:
        full_dir = os.path.join(artifact_dir, integer_dir)
        files = os.listdir(full_dir)
        part_files = filter(lambda file: file.startswith('part'), files)
        assert len(part_files) == 1, ('Did not find 1 {'
                                      '}'.format(integer_dir))
        part_file = part_files[0]
        shutil.copy(os.path.join(full_dir, part_file),
                    os.path.join(full_dir, 'mean.txt'))


def preprocess_categorical_dirs(artifact_dir):
    dirs = os.listdir(artifact_dir)
    categorical_dirs = filter(lambda dir: dir.startswith('categorical-feature'),
                          dirs)
    assert len(categorical_dirs) == 26, ('Expected 26 integer feature '
                                         'directories')
    for categorical_dir in categorical_dirs:
        full_dir = os.path.join(artifact_dir, categorical_dir)
        files = os.listdir(full_dir)
        part_file_name = filter(lambda file: file.startswith('part'), files)[0]
        print('Part file is {}'.format(part_file_name))
        with open(os.path.join(full_dir, part_file_name), 'r') as part_file:
            csvreader = csv.reader(part_file)
            features = [row[0] for row in csvreader]
        with open(os.path.join(full_dir, 'index.txt'), 'w') as index_file:
            for feature in features:
                if not feature:
                    feature = 'null'
                index_file.write('{}\n'.format(feature))
        with open(os.path.join(full_dir, 'count.txt'), 'w') as count_file:
            count_file.write('{}\n'.format(len(features)))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)

    parser.add_argument('artifact_dir')
    args = parser.parse_args()
    print('Processing integer dirs.')
    preprocess_integer_dirs(args.artifact_dir)
    print('Processing categorical dirs.')
    preprocess_categorical_dirs(args.artifact_dir)
    print('Done processing categories.')
