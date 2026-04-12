# Workloads

Workloads are separate git repositories submitted to the Hadoop cluster via `run-workload.sh`.

## Convention

Each workload repo must contain a `workload.sh` at its root. This script runs on the NameNode as `ec2-user` and is responsible for submitting the job to YARN.

```
my-workload/
├── workload.sh      # required: entry point, runs on the NameNode
├── input/           # optional: sample input data copied to HDFS
└── README.md
```

## Running a Workload

From inside the container:

```bash
/workspace/scripts/run-workload.sh https://github.com/org/my-workload.git
# or specify a branch:
/workspace/scripts/run-workload.sh https://github.com/org/my-workload.git dev
```

## Example workload.sh

```bash
#!/bin/bash
# WordCount example using bundled Hadoop MapReduce examples jar
set -euo pipefail

HADOOP_HOME=/opt/hadoop/current

# Upload input to HDFS
hdfs dfs -mkdir -p /user/hadoop/wordcount/input
hdfs dfs -put input/* /user/hadoop/wordcount/input/

# Run the job
hadoop jar "${HADOOP_HOME}/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar" \
    wordcount \
    /user/hadoop/wordcount/input \
    /user/hadoop/wordcount/output

# Print results
hdfs dfs -cat /user/hadoop/wordcount/output/part-r-00000 | head -20
```

## Environment Available in workload.sh

- `HADOOP_HOME` — `/opt/hadoop/current`
- `JAVA_HOME` — `/usr/lib/jvm/java-11-amazon-corretto`
- `hdfs`, `hadoop`, `yarn` — on PATH via `/etc/profile.d/hadoop.sh`
- YARN ResourceManager and HDFS NameNode are running and healthy before `workload.sh` executes
