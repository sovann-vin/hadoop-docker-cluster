#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Define HADOOP_HOME using default if not set (adjust version if needed)
: ${HADOOP_HOME:=/opt/hadoop-3.3.6}
# Define NameNode data directory for clarity
NN_DATA_DIR="$HADOOP_HOME/data/namenode"

# Check if NameNode needs formatting by looking for the VERSION file
# This is more robust than just checking for the 'current' directory existence
if [ ! -f "$NN_DATA_DIR/current/VERSION" ]; then
  echo "INFO: VERSION file not found in $NN_DATA_DIR/current. Formatting NameNode..."
  # Ensure any potentially incomplete 'current' directory is removed before format
  # Use 'rm -rf' carefully. Ensure NN_DATA_DIR is correctly defined.
  if [ -n "$NN_DATA_DIR" ]; then # Basic safety check
      rm -rf "$NN_DATA_DIR/current"
  fi
  # Run the format command
  hdfs namenode -format -force -nonInteractive
  echo "INFO: NameNode formatted."
else
  echo "INFO: VERSION file found in $NN_DATA_DIR/current. Skipping NameNode format."
fi

# Generate SSH host keys if they don't exist
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "INFO: Generating SSH host keys..."
    # Generate all default key types
    ssh-keygen -A
    echo "INFO: SSH host keys generated."
fi

# Create sshd privilege separation directory if it doesn't exist
if [ ! -d /run/sshd ]; then
    echo "INFO: Creating /run/sshd directory for sshd privilege separation..."
    mkdir -p /run/sshd
    # Optional: Set permissions if needed, though defaults are usually okay
    # chmod 755 /run/sshd
    echo "INFO: /run/sshd directory created."
fi

# Start SSH daemon in the background
echo "INFO: Starting sshd..."
/usr/sbin/sshd

# Start Hadoop HDFS Daemons
# This script starts NameNode and SecondaryNameNode on this machine,
# and DataNodes on machines listed in the 'workers' file via SSH.
echo "INFO: Starting HDFS (NameNode, DataNode on slaves, SecondaryNameNode)..."
start-dfs.sh

# Start Hadoop YARN Daemons
# This script starts ResourceManager on this machine,
# and NodeManagers on machines listed in the 'workers' file via SSH.
echo "INFO: Starting YARN (ResourceManager, NodeManager on slaves)..."
start-yarn.sh

# Start Job History Server
echo "INFO: Starting Job History Server..."
mapred --daemon start historyserver

echo "INFO: -------- Hadoop Cluster Started! Master is ready. --------"
echo "INFO: Access Web UIs (replace <host_ip> with your machine's IP or localhost):"
echo "INFO:   HDFS NameNode:         http://<host_ip>:9870"
echo "INFO:   YARN ResourceManager:  http://<host_ip>:8088"
echo "INFO:   MapReduce JobHistory:  http://<host_ip>:19888"
echo "INFO: -----------------------------------------------------------"

# Keep container running by tailing major logs
# Tail multiple logs and fall back to /dev/null if logs don't exist yet or are rotated
echo "INFO: Tailing Hadoop logs to keep container running..."
tail -f $HADOOP_HOME/logs/hadoop-*-namenode-*.log \
        $HADOOP_HOME/logs/hadoop-*-resourcemanager-*.log \
        $HADOOP_HOME/logs/mapred-*-historyserver-*.log \
        /var/log/sshd.log 2>/dev/null || tail -f /dev/null