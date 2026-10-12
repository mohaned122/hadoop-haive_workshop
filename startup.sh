#!/bin/bash

# Hadoop Auto-Startup Script
# This script loads environment variables and starts Hadoop automatically

echo "=========================================="
echo "HADOOP STARTUP SCRIPT"
echo "=========================================="
echo ""

# Load environment variables
source ~/.bashrc

# Check if JAVA_HOME is set
if [ -z "$JAVA_HOME" ]; then
    echo "ERROR: JAVA_HOME not set"
    exit 1
fi

echo "Starting Hadoop cluster..."
echo "JAVA_HOME: $JAVA_HOME"
echo "HADOOP_HOME: $HADOOP_HOME"
echo ""

# Start SSH if not running
if ! pgrep -x "sshd" > /dev/null; then
    echo "Starting SSH service..."
    service ssh start
    sleep 2
fi

# Wait a bit for system to be ready
sleep 2

# Start HDFS
echo "Starting HDFS..."
start-dfs.sh

sleep 5

# Start YARN
echo "Starting YARN..."
start-yarn.sh

sleep 5

# Show status
echo ""
echo "Hadoop cluster started. Running processes:"
jps

echo ""
echo "Web UIs:"
echo "  - NameNode: http://localhost:9870"
echo "  - ResourceManager: http://localhost:8088"
echo ""
echo "Keeping container alive..."

# Keep container running
tail -f /dev/null
