"""
This script defines spark-job steps for bigbench performance testing
"""

import os
import sys
import subprocess
from pyspark import SparkConf, SparkContext

# Configure the environment
if 'SPARK_HOME' not in os.environ:
    os.environ['SPARK_HOME'] = '/usr/lib/spark'

CONF = SparkConf().setAppName('pubmed_open_access').setMaster('local[32]')
SC = SparkContext(conf=CONF)


def execute_shell(cmd):
    """
    :param cmd:
    :return: stdout, err, return_code
    """
    popen_instance = subprocess.Popen(
        cmd,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    stdout, err = popen_instance.communicate()
    return_code = popen_instance.returncode
    return stdout, err, return_code


def run_benchmark(arg):
    """
    This method trigger benchmark execution
    """
    command = 'bash /Big-Data-Benchmark-for-Big-Bench/bin/bigBench runBenchmark {}'.format(arg)
    execute_shell(command)


def upload_results():
    """
    This method upload results to the bucket
    """
    cluster_name, err, return_code = execute_shell("/usr/share/google/get_metadata_value \
            attributes/dataproc-cluster-name")
    for file in os.listdir('/Big-Data-Benchmark-for-Big-Bench/logs/'):
        if file.__contains__(".csv") or file.__contains__(".zip"):
            output_path = "{}/{}/{}/".format(sys.argv[1], sys.argv[2], cluster_name)
            command = "gsutil cp /Big-Data-Benchmark-for-Big-Bench/logs/{} {}{}" \
                .format(file, output_path, file)
            execute_shell(command)


def main():
    """
    This method execute required benchmark actions and uploads results to the bucket
    """
    if len(sys.argv) > 3:
        if sys.argv[3] == "non-benchmark":
            print("Running non-benchmark option. \
                Empty times.csv file should be uploaded to specified bucket")
            command = "mkdir -p /Big-Data-Benchmark-for-Big-Bench/logs/ \
                && touch /Big-Data-Benchmark-for-Big-Bench/logs/sample.csv"
            execute_shell(command)
        else:
            print('benchmark with optional argument {}'.format(sys.argv[3]))
            run_benchmark(sys.argv[3])
    else:
        print("Running benchmark testing for scenario named {}".format(sys.argv[2]))
        run_benchmark(None)
    upload_results()


if __name__ == '__main__':
    main()
