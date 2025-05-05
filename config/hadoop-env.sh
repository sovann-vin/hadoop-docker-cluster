# Set Java Home
export JAVA_HOME=/usr/local/openjdk-8
export HADOOP_HOME=/opt/hadoop-3.3.6 # Adjust version if needed

# Default Hadoop Options
export HADOOP_OPTS="$HADOOP_OPTS -Djava.library.path=$HADOOP_HOME/lib/native"
export HADOOP_COMMON_LIB_NATIVE_DIR="$HADOOP_HOME/lib/native"

# Prevent ssh connection delays
export HADOOP_OPTS="$HADOOP_OPTS -Djava.net.preferIPv4Stack=true"

# Pass Hadoop user info
export HADOOP_USER_NAME=root # Running as root inside container for simplicity here
# Define users for Hadoop Daemons to allow running as root
# (Matches the USER set in the Dockerfile/container)
export HDFS_NAMENODE_USER="root"
export HDFS_DATANODE_USER="root"
export HDFS_SECONDARYNAMENODE_USER="root"
export YARN_RESOURCEMANAGER_USER="root"
export YARN_NODEMANAGER_USER="root"
YARN_NODEMANAGER_NICENESS=""