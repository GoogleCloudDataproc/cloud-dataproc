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
    p = subprocess.Popen(
        cmd,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    stdout, err = p.communicate()
    return_code = p.returncode
    return stdout, err, return_code


class Benchmark:
    clusterName = ""
    cluster_template_path = "cfg.yaml.tmpl"
    scenario_file_name = "testing_scenarios.yaml.tmpl"
    scenarios = []

    def run_workflow(self, scenario):
        command = "gcloud beta dataproc workflow-templates instantiate-from-file --file {} --format json".format(
            scenario.config_file_name)
        stdout, err, return_code = execute_shell(command)
        if return_code != 0:
            print("Workflow execution failed - Error code is {}".format(return_code))
            yaml_config = yaml.safe_load(open(scenario.config_file_name, 'r'))
            prefix = yaml_config['placement']['managedCluster']['clusterName']
            pattern = re.compile(r"{}-.*.".format(prefix))
            err = err.split()
            for element in err:
                if pattern.findall(str(element)):
                    self.clusterName = re.compile(r"{}-.*.".format(prefix)).findall(str(element))[0][:-2]
                    break
        else:
            data = json.loads(stdout.decode('utf-8'))
            self.clusterName = data['metadata']['clusterName']

    def upload_config_to_gs(self, scenario):
        yaml_config = yaml.safe_load(open(scenario.config_file_name, 'r'))
        scenario_destination_bucket_path = "{}/{}/{}/cfg.yaml".format(
            yaml_config['jobs']['pysparkJob']['args'][0],
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
        stream = open(self.scenario_file_name, 'r')
        scenarios = yaml.safe_load(stream)
        stream.close()
        return scenarios

    def read_template_yaml(self):
        stream = open(self.cluster_template_path, 'r')
        template = yaml.safe_load(stream)
        stream.close()
        return template

    def write_scenarios_yaml(self, data, scenario):
        stream = open("{}-{}".format(scenario, "cfg.yaml"), 'w')
        yaml.dump(data, stream, default_flow_style=False)
        stream.close()

    def merge_dicts(self, d1, d2):
        """
        Recursively overrides items in d1 based on keys/values from d2
        Input dictionaries must have common scheme
        """
        for override_key, override_item in d2.items():
            if override_key in d1:
                if isinstance(override_item, dict):
                    self.merge_dicts(d1[override_key], override_item)
                elif isinstance(override_item, list):
                    d1[override_key] = [i[1] for i in zip(d1[override_key], override_item)]
                else:
                    d1[override_key] = override_item
            else:
                d1[override_key] = override_item

    def merge_configs(self):
        """Apply config from scenario to template"""
        scenarios_file = self.read_scenarios_yaml()
        for scenario in scenarios_file:
            base_config = self.read_template_yaml()
            # Iterate over scenarios_file
            scenario_dict = scenarios_file[scenario]
            self.merge_dicts(base_config, scenario_dict)
            if os.path.exists("{}-{}".format(scenario, "cfg.yaml")):
                print("{}-{}".format(scenario, "cfg.yaml") + " already exists will be overwritten.")
            self.write_scenarios_yaml(base_config, scenario)
            self.scenarios.append(Scenario(scenario, "{}-{}".format(scenario, "cfg.yaml")))
