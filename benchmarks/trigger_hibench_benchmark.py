"""
This script defines spark-job steps for hibench performance testing
"""
import os
import sys
import subprocess
import fileinput
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


def run_benchmark():
    """
    This method trigger benchmark execution
    """
    cmd = 'bash /HiBench/bin/run_all.sh'
    execute_shell(cmd)


def upload_results():
    """
    This method upload results to the bucket
    """
    cluster_name = os.popen("/usr/share/google/get_metadata_value \
                            attributes/dataproc-cluster-name") \
        .read()
    output_path = "{}/{}/{}/hibench.report".format(sys.argv[1], sys.argv[2], cluster_name)
    cmd = "gsutil cp /HiBench/report/hibench.report {}".format(output_path)
    execute_shell(cmd)


def set_hibench_scale_profile(profile):
    """
    This method replace a default scale profile inside hibench.conf file and set given value
    Available value is tiny, small, large, huge, gigantic and bigdata.
    :param profile: scale factor
    """
    for n, line in enumerate(fileinput.input('/HiBench/conf/hibench.conf', inplace=True), start=1):
        if 'hibench.scale.profile' in line:
            line = "hibench.scale.profile     {}\n".format(profile)
        print(line)


def main():
    """
    This method execute required benchmark actions and uploads results to the bucket
    """
    if len(sys.argv) > 3:
        if sys.argv[3] == "non-benchmark":
            print("Running non-benchmark option. \
            Empty hibench.report file should be uploaded to specified bucket")
            os.mkdir('/HiBench/report/')
            open('/HiBench/report/hibench.report', 'w+').close()
        else:
            print('benchmark with optional argument {}'.format(sys.argv[3]))
            set_hibench_scale_profile(sys.argv[3])
            run_benchmark()
    else:
        print("Running benchmark testing for scenario named {}".format(sys.argv[2]))
        run_benchmark()
    upload_results()


if __name__ == '__main__':
    main()
