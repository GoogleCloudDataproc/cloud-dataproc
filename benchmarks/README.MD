# This repository contains scripts for running Benchmark tests

## Prerequisites
- Python 3.6 installed.
- Requirements satisfied:
    ```bash
    pip install -r requirements.txt
    ```

- `gcloud` command line tool installed and configured(GCP project is set).
- gcloud beta components installed:
    ```bash
    gcloud components install beta
    ```

## Running benchmarks
1. You must provide a valid GCS bucket name for uploading results in [scenario job arguments](https://github.com/GoogleCloudPlatform/cloud-dataproc/blob/master/benchmarks/testing_scenarios.yaml.tmpl#L6) and update [the workflow name](https://github.com/GoogleCloudPlatform/cloud-dataproc/blob/master/benchmarks/cfg.yaml.tmpl#L2) with the right project name.
1. You can launch performance testing by calling:
    ```bash 
    python runPerformanceTesting.py
    ```
    
    The command will create workflow files `scenario_1-cfg.yaml` and `scenario_2-cfg.yaml` based on default template files `cfg.yaml.tmpl` and `testing_scenarios.yaml.tmpl` and then submit them one by one using gcloud beta commands.
    Please note that this will create cluster and submit job based on what is `scenario_1-cfg.yaml` and after completed the same will happen for workflow file `scenario_2-cfg.yaml`.
    This could be avoided by passing `--dry_run` flag that only creates workflow files.
    
1. You can parametrize performance testing by changing default settings in templates or providing your own.
You can pass following optional parameters:
    - --scenarios - file with scenarios definitions that override template values
    - --template - filename for yaml template with default configuration
    - --dry_run - running mode that only produces workflow files without submitting them

1. Typical execution of custom scenario can be performed by creating yaml file based on `testing_scenarios.yaml.tmpl` with *all parameters* you would like to overwrite in `cfg.yaml.tmpl` and passing it to script with:
    ```bash
    python runPerformanceTesting.py --scenarios <your_custom_scenario_file> 
    ``` 
    
## Template file explained
### Workflow file: cfg.yaml.tmpl
1. id - workflow id. 
1. name - workflow name it contains project name, so you must `update` it.
1. placement - contains hardware and software parameters of the cluster.


### Scenarios file: testing_scenarios.yaml.tmpl
1. scenario_1 - scenario name. Root key with overrides to template listed underneath:
    1. jobs - list of the jobs that will be passed to workflow in our case we are using "PySpark" job.
    1. Arguments for pyspark job:
        1. path to directory on bucket where results should be stored
        1. scenario_name
        1. optional arguments for `BigBench.sh runBenchmark` command, ie. `non-benchmark`, '-e spark_sql' or `-f 1`. For HiBench benchmark data set can be adjusted by passing tiny,small,huge words - see more
        Note: by passing `non-benchmark` you can test whole flow of cluster creation, submitting job, creating empty csv file and uploading it to bucket without running any benchmark.
        This option is available for both BigBench and HiBench. 
    1. placement - list of software and parameters to override in workflow template file. Placement contains object of [managed cluster](https://cloud.google.com/dataproc/docs/reference/rest/v1beta2/ClusterConfig). 

Inside scenario placement section it can be specified which engine (instead of default hive) should be used for benchmark execution. This value should be held under `gceClusterConfig` section as metadata attribute:
```
        metadata:
          benchmark_engine: spark_sql
```
In order to trigger specified engine, it should be also specified optional argument (3rd one) `-e spark_sql`.

### Overriding system properties
1. There are two system properties supported that could be set in workflow: `swap_size` and `file_handle_limit`. You can specify their values in scenario file under config -> gceClusterConfig->metadata. Example in: testing_scenarios.yaml.tmpl.
Metadata value type must be an unicode, so please use quotes when passing numbers. For swap size parameter adding unit suffix is required.
```
    config:
      gceClusterConfig:
        metadata:
          file_handle_limit: '10000000'
          swap_size: 5G
```

## Running unit tests

```bash
python unittests.py
```
## Examples
Initial benchmark directory contains configuration file for BigBench tests and scenarios examples.
There are example testing scenarios for various testing parameters:

- CPU:

```bash
python runPerformanceTesting.py --scenarios initial_benchmark/cpu-testing-scenarios.yaml --template initial_benchmark/cfg-1.yaml
```

- BigBench testing using hive:

```bash
python runPerformanceTesting.py --scenarios examples/bigbench-hive-scenarios.yaml --template examples/cfg-dataproc-1.3.yaml
```

- BigBench testing using spark_sql:

```bash
python runPerformanceTesting.py --scenarios examples/bigbench-spark-sql-scenarios.yaml --template examples/cfg-dataproc-1.3.yaml
```

- HiBench using tiny dataset:

```bash
python runPerformanceTesting.py --scenarios examples/hibench-dataproc-1-2-scenarios.yaml --template examples/cfg-dataproc-1.3.yaml
```
