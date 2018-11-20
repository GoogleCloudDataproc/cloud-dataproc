'''
This script triggers performance testing
'''

import argparse
import threading
from benchmarkUtil import Benchmark


def trigger_workflow(scenario, benchmark):
    benchmark.run_workflow(scenario)
    print("Scenario {} has finished".format(scenario.name))
    benchmark.upload_config_to_gs(scenario)


if __name__ == '__main__':
    PARSER = argparse.ArgumentParser()
    PARSER.add_argument("--scenarios", action="store",
                        help="File contains scenarios definition \
                        for running Bigbench/Highbench tests \
                        on various configurations")
    PARSER.add_argument("--template", action="store",
                        help="File that contains a default config template file \
                        that would be overriden by scenarios")
    PARSER.add_argument("--dry_run", action="store_true",
                        help="If enabled it allows for config files preparation \
                        without workflow execution")
    PARSER.add_argument("--parallel", action="store_true",
                        help="If enabled all scenarios will be executed \
                        in parallel mode")

    ARGS = PARSER.parse_args()
    BENCHMARK = Benchmark()
    if ARGS.scenarios:
        BENCHMARK.set_scenarios_file(ARGS.scenarios)
    if ARGS.template:
        BENCHMARK.set_config_template_file(ARGS.template)
    BENCHMARK.merge_configs()
    if not ARGS.dry_run:
        print("---Starting performance testing---")
        for scenario in BENCHMARK.scenarios:
            print("Starting performance testing for {} using {} configuration file"
                  .format(scenario.name, scenario.config_file_name))
            if ARGS.parallel:
                threading.Thread(target=trigger_workflow, args=(scenario, BENCHMARK)).start()
            else:
                trigger_workflow(scenario, BENCHMARK)
