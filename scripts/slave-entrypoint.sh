#!/bin/bash
set -e

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

# --- Add this line ---
# Ensure Hadoop log directory exists (use the correct HADOOP_HOME path)
mkdir -p /opt/hadoop-3.3.6/logs
# --- End of line to add ---

# Execute the original command (sshd -D)
echo "Slave: Starting sshd in foreground..."
exec /usr/sbin/sshd -D