""" This module run unit tests """
import os
import unittest
import yaml
from mock import patch
from benchmarkUtil import Benchmark


TESTFILE1="/tmp/scenario_1-cfg.yaml"
TESTFILE2="/tmp/scenario_2-cfg.yaml"


class VerifyBenchmarking(unittest.TestCase):
    """ This class wrap all unit tests in single scenario."""

    def setUp(self):
        print("Test name:", self._testMethodName)

    def tearDown(self):
        if os.path.exists(TESTFILE1):
            os.remove(TESTFILE1)
        if os.path.exists(TESTFILE2):
            os.remove(TESTFILE2)

    def read_yaml(self, yaml_name):
        """Safely open, read and close any yaml file."""
        with open(yaml_name, 'r') as stream:
            return yaml.safe_load(stream)

    def test_job_is_merged_with_good_arguments(self):
        """Testing passing PySpark job and its args."""
        Benchmark.merge_configs(Benchmark())
        result_config = self.read_yaml(TESTFILE1)
        job = result_config['jobs'][0]["pysparkJob"]
        self.assertEqual(job["mainPythonFileUri"], "gs://dataproc-benchmarking/benchmarks/trigger_bigbench_benchmark.py")
        self.assertEqual(len(job["args"]), 3)

    @patch('benchmarkUtil.Benchmark.read_scenarios_yaml',
           return_value={'scenario_1':
                             {'placement':
                                  {'managedCluster':
                                       {'config':
                                            {'masterConfig':
                                                 {'numInstances': 15}}}}}})
    def test_yaml_master_number_passing(self, *args):
        """Testing passing custom number of instances to cluster settings"""
        Benchmark.merge_configs(Benchmark())
        result_config = self.read_yaml(TESTFILE1)
        self.assertEqual(result_config['placement']['managedCluster']['config']
                         ['masterConfig']['numInstances'], 15)

    @patch('benchmarkUtil.Benchmark.read_scenarios_yaml',
           return_value={'scenario_2':
                             {'placement':
                                  {'managedCluster':
                                       {'config':
                                            {'initializationActions':
                                                 {'executableFile':
                                                      'gs://bucket-name/hibench.sh'}}}}}})
    def test_yaml_init_action_passing(self, *args):
        """Testing passing init action to cluster settings"""
        Benchmark.merge_configs(Benchmark())
        result_config = self.read_yaml(TESTFILE2)
        self.assertEqual(result_config['placement']['managedCluster']['config']
                         ['initializationActions']['executableFile'],
                         "gs://bucket-name/hibench.sh")

    @patch('benchmarkUtil.Benchmark.read_scenarios_yaml',
           return_value={'scenario_2':
                             {'placement':
                                  {'managedCluster':
                                       {'config':
                                            {'softwareConfig':
                                                 {'properties':
                                                      {'mapreduce.map.cpu.vcores': 8}}}}}}})
    def test_software_prop_passing(self, *args):
        """Testing software properties passing"""
        Benchmark.merge_configs(Benchmark())
        result_config = self.read_yaml(TESTFILE2)
        self.assertEqual(result_config['placement']['managedCluster']['config']
                         ['softwareConfig']['properties']['mapreduce.map.cpu.vcores'], 8)


if __name__ == '__main__':
    unittest.main()
