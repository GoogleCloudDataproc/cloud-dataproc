import json
import yaml
import subprocess
import os
import re


class Scenario:
    def __init__(self, name, config_file_path):
        self.name = name
        self.config_file_name = config_file_path


def execute_shell(cmd):
    print("Running command {}".format(cmd))
    p = subprocess.Popen(
        cmd,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    stdout, stderr = p.communicate()
    return_code = p.returncode
    return stdout, stderr, return_code


class Benchmark:
    clusterName = ""
    cluster_template_path = "cfg.yaml.tmpl"
    scenario_file_name = "testing_scenarios.yaml.tmpl"
    scenarios = []

    def run_workflow(self, scenario):
        command = "gcloud dataproc workflow-templates instantiate-from-file --file {} --format json".format(
            scenario.config_file_name)
        stdout, stderr, return_code = execute_shell(command)
        if return_code != 0:
            print("Workflow execution failed - Error code is {}".format(return_code))
            print("STDOUT:\n {}\n".format(stdout))
            print("STDERR:\n {}\n".format(stderr))
            yaml_config = yaml.safe_load(open(scenario.config_file_name, 'r'))
            prefix = yaml_config['placement']['managedCluster']['clusterName']
            pattern = re.compile(r"{}-.*.".format(prefix))
            stderr = stderr.split()
            for element in stderr:
                if pattern.findall(str(element)):
                    self.clusterName = re.compile(r"{}-.*.".format(prefix)).findall(str(element))[0][:-2]
                    break
        else:
            data = json.loads(stdout.decode('utf-8'))
            self.clusterName = data['metadata']['clusterName']

    def upload_config_to_gs(self, scenario):
        yaml_config = yaml.safe_load(open(scenario.config_file_name, 'r'))
        experiment_name = yaml_config['jobs'][0]['pysparkJob']['args'][0]
        scenario_destination_bucket_path = "{}/{}/{}/cfg.yaml".format(
            experiment_name,
            scenario.name,
            self.clusterName)
        command = "gsutil cp {} {} ".format(scenario.config_file_name,
                                            scenario_destination_bucket_path)
        execute_shell(command)

        print('File {} uploaded to {}. as cfg.yml'.format(
            scenario.config_file_name,
            scenario_destination_bucket_path))

    def set_config_template_file(self, tmpl):
        self.cluster_template_path = tmpl

    def set_scenarios_file(self, scenarios):
        self.scenario_file_name = scenarios

    def read_scenarios_yaml(self):
        with open(self.scenario_file_name, 'r') as stream:
            return yaml.safe_load(stream)

    def read_template_yaml(self):
        with open(self.cluster_template_path, 'r') as stream:
            return yaml.safe_load(stream)

    def write_scenarios_yaml(self, data, scenario, scenario_file):
        with open(scenario_file, 'w') as stream:
            yaml.dump(data, stream, default_flow_style=False)

    def merge_dicts(self, original, override):
        """
        Recursively overrides items in original based on keys/values from override.
        Input dictionaries must have common scheme.
        """
        for override_key, override_item in override.items():
            if override_key in original:
                if isinstance(override_item, dict):
                    self.merge_dicts(original[override_key], override_item)
                elif isinstance(override_item, list):
                    original_list = original[override_key]
                    if original_list is None:
                      original[override_key] = override_item
                    else:
                      for idx, item in enumerate(override_item):
                          if isinstance(item, dict):
                              self.merge_dicts(original_list[idx], item)
                          else:
                              original_list[idx] = item
                else:
                    original[override_key] = override_item
            else:
                original[override_key] = override_item

    def merge_configs(self):
        """Apply config from scenario to template."""
        scenarios = self.read_scenarios_yaml()
        for scenario in scenarios:
            base_config = self.read_template_yaml()
            # Iterate over scenarios_file
            scenario_dict = scenarios[scenario]
            self.merge_dicts(base_config, scenario_dict)
            scenario_file = "{}/{}-{}".format("/tmp",scenario, "cfg.yaml")
            if os.path.exists(scenario_file):
                print(scenario_file + " already exists will be overwritten.")
            self.write_scenarios_yaml(base_config, scenario, scenario_file)
            self.scenarios.append(Scenario(scenario, scenario_file))
