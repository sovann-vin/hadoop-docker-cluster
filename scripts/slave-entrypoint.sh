#!/bin/bash
set -e

: ${HADOOP_HOME:=/opt/hadoop-3.3.6}
# Default temp dir based on core-site.xml
HADOOP_TMP_DIR=/opt/hadoop_tmp/data

# Generate SSH host keys if they don't exist
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "Slave: Generating SSH host keys..."
    ssh-keygen -A
    echo "Slave: SSH host keys generated."
fi

# Create sshd privilege separation directory if needed
if [ ! -d /run/sshd ]; then
    mkdir -p /run/sshd
fi

# --- Add/Ensure these lines exist ---
echo "Slave: Ensuring Hadoop directories exist..."
mkdir -p $HADOOP_HOME/logs
# Create default NM dirs under hadoop.tmp.dir
mkdir -p $HADOOP_TMP_DIR/nm-local-dir
mkdir -p $HADOOP_TMP_DIR/usercache
# Ensure log dir for NM also exists (often overlaps with HADOOP_HOME/logs)
mkdir -p $HADOOP_HOME/logs/userlogs # Default location for yarn.nodemanager.log-dirs often includes this
# Optional: Set ownership/permissions if needed, though root should own by default
# chown root:root $HADOOP_HOME/logs $HADOOP_TMP_DIR ...
echo "Slave: Hadoop directories checked/created."
# --- End Add/Ensure ---

# Execute the original command (sshd -D)
echo "Slave: Starting sshd in foreground..."
exec /usr/sbin/sshd -D