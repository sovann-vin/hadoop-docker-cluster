#!/bin/bash
set -e # Exit on error

# Check if NameNode is formatted
if [ ! -d "$HADOOP_HOME/data/namenode/current" ]; then
  echo "Formatting NameNode..."
  hdfs namenode -format -force -nonInteractive
  echo "NameNode formatted."
fi

# Generate SSH host keys if they don't exist
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "Generating SSH host keys..."
    ssh-keygen -A
    echo "SSH host keys generated."
# else # Optional: Remove the 'else' block with the ls command
    # echo "SSH host keys seem to exist already."
    # echo "Listing existing /etc/ssh keys:"
    # ls -l /etc/ssh/ssh_host_*_key* || echo "[DEBUG] Could not list existing keys!"
fi

# Create sshd privilege separation directory if it doesn't exist
if [ ! -d /run/sshd ]; then
    echo "Creating /run/sshd directory for sshd privilege separation..."
    mkdir -p /run/sshd
    echo "/run/sshd directory created."
fi

# Start SSH daemon in the background
echo "Starting sshd..."
/usr/sbin/sshd # <--- Reverted to original command (runs as daemon)

# Start Hadoop services
echo "Starting HDFS..."
start-dfs.sh

echo "Starting YARN..."
start-yarn.sh

echo "Starting Job History Server..."
mapred --daemon start historyserver

echo "Hadoop Cluster Started! Master is ready."
echo "Access Web UIs:"
echo "  Namenode:    http://localhost:9870"
echo "  YARN RM:     http://localhost:8088"
echo "  MR History:  http://localhost:19888"

# Keep container running
tail -f $HADOOP_HOME/logs/hadoop-*-namenode-*.log $HADOOP_HOME/logs/hadoop-*-resourcemanager-*.log $HADOOP_HOME/logs/mapred-*-historyserver-*.log /var/log/sshd.log 2>/dev/null || tail -f /dev/null