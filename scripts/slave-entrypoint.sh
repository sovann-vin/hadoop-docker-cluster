#!/bin/bash
set -e # Exit on error

# Generate SSH host keys if they don't exist
# Use a slightly different echo message for clarity in logs
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "Slave: Generating SSH host keys..."
    ssh-keygen -A
    echo "Slave: SSH host keys generated."
fi

# Create sshd privilege separation directory if needed (proactive check)
if [ ! -d /run/sshd ]; then
    mkdir -p /run/sshd
fi

# Execute the original intended command for slaves (sshd -D)
# 'exec' replaces the script process with sshd, which is good practice here
echo "Slave: Starting sshd in foreground..."
exec /usr/sbin/sshd -D