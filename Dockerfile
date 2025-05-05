# Use an OpenJDK base image
FROM openjdk:8-jdk-slim

# Set environment variables (adjust Hadoop version as needed)
ARG HADOOP_VERSION=3.3.6

ENV HADOOP_VERSION=${HADOOP_VERSION}
ENV HADOOP_HOME=/opt/hadoop-${HADOOP_VERSION}
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
# Run as root for simplicity in this example
ENV USER=root

# Install dependencies: ssh, rsync, wget
RUN apt-get update && apt-get install -y --no-install-recommends \
    ssh \
    rsync \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Download and unpack Hadoop
RUN wget https://downloads.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz -O /tmp/hadoop.tar.gz && \
    tar -xzf /tmp/hadoop.tar.gz -C /opt && \
    rm /tmp/hadoop.tar.gz

# Setup SSH server configuration
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#StrictModes yes/StrictModes no/' /etc/ssh/sshd_config && \
    # Regenerate host keys on first boot
    rm -f /etc/ssh/ssh_host_*_key

# Copy pre-generated SSH keys and set permissions
COPY ssh/id_rsa /root/.ssh/id_rsa
COPY ssh/id_rsa.pub /root/.ssh/id_rsa.pub
COPY ssh/authorized_keys /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/id_rsa && \
    chmod 604 /root/.ssh/id_rsa.pub && \
    chmod 600 /root/.ssh/authorized_keys

# Copy the master entrypoint script and make it executable
COPY scripts/entrypoint.sh /opt/scripts/entrypoint.sh
RUN chmod +x /opt/scripts/entrypoint.sh    

# Add these lines, perhaps near the other COPY/chmod lines for scripts
COPY scripts/slave-entrypoint.sh /opt/scripts/slave-entrypoint.sh
RUN chmod +x /opt/scripts/slave-entrypoint.sh

# Copy Hadoop configurations
COPY config/* $HADOOP_CONF_DIR/

# Expose Hadoop ports (for reference, mapping is done in docker-compose)
# HDFS Ports
EXPOSE 9000 9870 9868 9867 9866 9864 9820
# YARN Ports
EXPOSE 8030 8031 8032 8033 8040 8042 8088
# MapReduce JobHistory Server Port
EXPOSE 10020 19888

# Default command (can be overridden in docker-compose)
CMD ["/usr/sbin/sshd", "-D"]