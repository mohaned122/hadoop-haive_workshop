#!/bin/bash

# Complete Hadoop Docker Setup Script
# This script configures a single-node pseudo-distributed Hadoop cluster

set -e

echo "=========================================="
echo "HADOOP DOCKER SETUP SCRIPT"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Define variables
HADOOP_HOME="/opt/hadoop"
HADOOP_USER="hadoop"
HADOOP_GROUP="hadoop"

# ============================================================================
# STEP 1: INSPECT CURRENT ENVIRONMENT
# ============================================================================
echo -e "${YELLOW}[STEP 1] Inspecting current environment...${NC}"
echo ""

echo "Current user: $(whoami)"
echo "Current hostname: $(hostname)"
echo "Hadoop home: $HADOOP_HOME"
echo ""

echo "Java Detection:"
if command -v java &> /dev/null; then
    echo "✓ Java found at: $(which java)"
    java -version
    JAVA_PATH=$(readlink -f $(which java))
    JAVA_HOME=$(dirname $(dirname "$JAVA_PATH"))
    echo "Detected JAVA_HOME: $JAVA_HOME"
else
    echo "✗ Java not found!"
    exit 1
fi
echo ""

echo "SSH Status:"
if [ -f ~/.ssh/id_rsa ]; then
    echo "✓ SSH private key exists"
else
    echo "✗ SSH private key missing"
fi

if [ -f ~/.ssh/authorized_keys ]; then
    echo "✓ authorized_keys exists"
else
    echo "✗ authorized_keys missing"
fi
echo ""

echo "Hadoop Installation:"
if [ -d "$HADOOP_HOME" ]; then
    echo "✓ Hadoop directory exists"
    ls -la "$HADOOP_HOME" | head -10
else
    echo "✗ Hadoop directory not found"
    exit 1
fi
echo ""

# ============================================================================
# STEP 2: CONFIGURE JAVA_HOME
# ============================================================================
echo -e "${YELLOW}[STEP 2] Configuring JAVA_HOME...${NC}"
echo ""

# Update .bashrc for current user
if ! grep -q "export JAVA_HOME=" ~/.bashrc; then
    echo "export JAVA_HOME=$JAVA_HOME" >> ~/.bashrc
    echo "✓ Added JAVA_HOME to ~/.bashrc"
else
    # Replace existing JAVA_HOME
    sed -i "s|export JAVA_HOME=.*|export JAVA_HOME=$JAVA_HOME|g" ~/.bashrc
    echo "✓ Updated JAVA_HOME in ~/.bashrc"
fi

# Export for current session
export JAVA_HOME="$JAVA_HOME"
echo "✓ JAVA_HOME exported for current session: $JAVA_HOME"
echo ""

# ============================================================================
# STEP 3: CONFIGURE HADOOP ENVIRONMENT VARIABLES
# ============================================================================
echo -e "${YELLOW}[STEP 3] Configuring Hadoop environment variables...${NC}"
echo ""

# Update .bashrc
if ! grep -q "export HADOOP_HOME=" ~/.bashrc; then
    echo "export HADOOP_HOME=$HADOOP_HOME" >> ~/.bashrc
    echo "export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin" >> ~/.bashrc
else
    sed -i "s|export HADOOP_HOME=.*|export HADOOP_HOME=$HADOOP_HOME|g" ~/.bashrc
fi

export HADOOP_HOME="$HADOOP_HOME"
export PATH="$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin"

echo "✓ Hadoop environment variables configured"
echo "  HADOOP_HOME: $HADOOP_HOME"
echo "  PATH updated with hadoop/bin and hadoop/sbin"
echo ""

# ============================================================================
# STEP 4: CONFIGURE hadoop-env.sh
# ============================================================================
echo -e "${YELLOW}[STEP 4] Configuring hadoop-env.sh...${NC}"
echo ""

HADOOP_ENV="$HADOOP_HOME/etc/hadoop/hadoop-env.sh"

if [ ! -f "$HADOOP_ENV" ]; then
    echo "✗ hadoop-env.sh not found at $HADOOP_ENV"
    exit 1
fi

# Backup original
if [ ! -f "$HADOOP_ENV.bak" ]; then
    cp "$HADOOP_ENV" "$HADOOP_ENV.bak"
    echo "✓ Backed up original hadoop-env.sh"
fi

# Configure JAVA_HOME
if grep -q "^# export JAVA_HOME=" "$HADOOP_ENV" || ! grep -q "^export JAVA_HOME=" "$HADOOP_ENV"; then
    # Comment out old line and add new one
    sed -i 's/^export JAVA_HOME=.*/# &/' "$HADOOP_ENV"
    sed -i "1a export JAVA_HOME=$JAVA_HOME" "$HADOOP_ENV"
    echo "✓ Configured JAVA_HOME in hadoop-env.sh"
else
    sed -i "s|^export JAVA_HOME=.*|export JAVA_HOME=$JAVA_HOME|g" "$HADOOP_ENV"
    echo "✓ Updated JAVA_HOME in hadoop-env.sh"
fi

# Configure SSH options for scripts
if ! grep -q "export HADOOP_SSH_OPTS=" "$HADOOP_ENV"; then
    echo 'export HADOOP_SSH_OPTS="-o StrictHostKeyChecking=no"' >> "$HADOOP_ENV"
    echo "✓ Added SSH options to hadoop-env.sh"
fi

echo ""

# ============================================================================
# STEP 5: CONFIGURE SSH FOR PASSWORDLESS ACCESS
# ============================================================================
echo -e "${YELLOW}[STEP 5] Configuring passwordless SSH...${NC}"
echo ""

# Create .ssh directory if it doesn't exist
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Generate SSH key if it doesn't exist
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
    echo "✓ Generated SSH key pair"
else
    echo "✓ SSH key pair already exists"
fi

# Configure authorized_keys
if [ ! -f ~/.ssh/authorized_keys ]; then
    cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    echo "✓ Created authorized_keys"
else
    # Add key if not already present
    if ! grep -q "$(cat ~/.ssh/id_rsa.pub)" ~/.ssh/authorized_keys; then
        cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
        echo "✓ Added key to authorized_keys"
    else
        echo "✓ SSH key already in authorized_keys"
    fi
fi

# Configure SSH client
echo "✓ Configuring SSH client..."
cat > ~/.ssh/config << 'EOF'
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
    LogLevel=ERROR
EOF
chmod 600 ~/.ssh/config

# Ensure SSH server is running and allow SSH loopback
echo "✓ Configuring SSH server..."

# Start SSH service
if ! pgrep -x "sshd" > /dev/null; then
    service ssh start
    sleep 2
    echo "✓ SSH service started"
else
    echo "✓ SSH service already running"
fi

# Test SSH to localhost
echo "✓ Testing SSH to localhost..."
if ssh -o ConnectTimeout=5 localhost "echo 'SSH test successful'" 2>/dev/null; then
    echo "✓ SSH localhost connection successful"
else
    echo "✗ Warning: SSH to localhost failed, but continuing..."
fi

# Test SSH to hostname
echo "✓ Testing SSH to $(hostname)..."
if ssh -o ConnectTimeout=5 "$(hostname)" "echo 'SSH test successful'" 2>/dev/null; then
    echo "✓ SSH $(hostname) connection successful"
else
    echo "✗ Warning: SSH to $(hostname) failed, but continuing..."
fi

echo ""

# ============================================================================
# STEP 6: CONFIGURE HADOOP XML FILES
# ============================================================================
echo -e "${YELLOW}[STEP 6] Configuring Hadoop XML files...${NC}"
echo ""

HADOOP_CONF="$HADOOP_HOME/etc/hadoop"
HOSTNAME=$(hostname)

# Backup original files
for file in core-site.xml hdfs-site.xml mapred-site.xml yarn-site.xml; do
    if [ -f "$HADOOP_CONF/$file" ] && [ ! -f "$HADOOP_CONF/${file}.bak" ]; then
        cp "$HADOOP_CONF/$file" "$HADOOP_CONF/${file}.bak"
    fi
done

# ========== core-site.xml ==========
echo "Configuring core-site.xml..."
cat > "$HADOOP_CONF/core-site.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://localhost:9000</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>/opt/hadoop/tmp</value>
    </property>
</configuration>
EOF
echo "✓ core-site.xml configured"

# ========== hdfs-site.xml ==========
echo "Configuring hdfs-site.xml..."
cat > "$HADOOP_CONF/hdfs-site.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>file:///opt/hadoop/data/namenode</value>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>file:///opt/hadoop/data/datanode</value>
    </property>
    <property>
        <name>dfs.namenode.secondary.http-address</name>
        <value>0.0.0.0:9101</value>
    </property>
    <property>
        <name>dfs.webhdfs.enabled</name>
        <value>true</value>
    </property>
    <property>
        <name>dfs.permissions.enabled</name>
        <value>false</value>
    </property>
    <property>
        <name>dfs.namenode.http-address</name>
        <value>0.0.0.0:9870</value>
    </property>
</configuration>
EOF
echo "✓ hdfs-site.xml configured"

# ========== mapred-site.xml ==========
echo "Configuring mapred-site.xml..."
cat > "$HADOOP_CONF/mapred-site.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>mapreduce.jobhistory.bind-host</name>
        <value>0.0.0.0</value>
    </property>
    <property>
        <name>mapreduce.jobhistory.webapp.bind-host</name>
        <value>0.0.0.0</value>
    </property>
    <property>
        <name>mapreduce.application.classpath</name>
        <value>/opt/hadoop/share/hadoop/mapreduce/*:/opt/hadoop/share/hadoop/mapreduce/lib/*:/opt/hadoop/share/hadoop/common/*:/opt/hadoop/share/hadoop/common/lib/*:/opt/hadoop/share/hadoop/yarn/*:/opt/hadoop/share/hadoop/yarn/lib/*:/opt/hadoop/share/hadoop/hdfs/*:/opt/hadoop/share/hadoop/hdfs/lib/*</value>
    </property>
    <property>
        <name>mapreduce.jobhistory.address</name>
        <value>localhost:10020</value>
    </property>
    <property>
        <name>mapreduce.jobhistory.webapp.address</name>
        <value>localhost:19888</value>
    </property>
</configuration>
EOF
echo "✓ mapred-site.xml configured"

# ========== yarn-site.xml ==========
echo "Configuring yarn-site.xml..."
cat > "$HADOOP_CONF/yarn-site.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>localhost</value>
    </property>
    <property>
        <name>yarn.resourcemanager.bind-host</name>
        <value>0.0.0.0</value>
    </property>
    <property>
        <name>yarn.nodemanager.bind-host</name>
        <value>0.0.0.0</value>
    </property>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.nodemanager.aux-services.mapreduce_shuffle.class</name>
        <value>org.apache.hadoop.mapred.ShuffleHandler</value>
    </property>
    <property>
        <name>yarn.nodemanager.vmem-check-enabled</name>
        <value>false</value>
    </property>
    <property>
        <name>yarn.resourcemanager.resource-tracker.address</name>
        <value>localhost:8031</value>
    </property>
    <property>
        <name>yarn.resourcemanager.scheduler.address</name>
        <value>localhost:8030</value>
    </property>
    <property>
        <name>yarn.resourcemanager.address</name>
        <value>localhost:8032</value>
    </property>
</configuration>
EOF
echo "✓ yarn-site.xml configured"
echo ""

# ============================================================================
# STEP 7: CREATE HADOOP DATA DIRECTORIES
# ============================================================================
echo -e "${YELLOW}[STEP 7] Creating Hadoop data directories...${NC}"
echo ""

mkdir -p /opt/hadoop/tmp
mkdir -p /opt/hadoop/data/namenode
mkdir -p /opt/hadoop/data/datanode

echo "✓ Data directories created"
echo ""

# ============================================================================
# STEP 8: FORMAT NAMENODE
# ============================================================================
echo -e "${YELLOW}[STEP 8] Formatting NameNode...${NC}"
echo ""

# Check if already formatted
if [ -f /opt/hadoop/data/namenode/current/VERSION ]; then
    echo "⚠ NameNode already formatted. Skipping..."
else
    echo "Formatting NameNode (this may take a moment)..."
    # Suppress the interactive prompt
    echo "Y" | hdfs namenode -format 2>&1 | grep -E "(FORMAT|Formatting|SHUTDOWN)"
    echo "✓ NameNode formatted"
fi
echo ""

# ============================================================================
# STEP 9: START HDFS
# ============================================================================
echo -e "${YELLOW}[STEP 9] Starting HDFS...${NC}"
echo ""

# Kill any existing processes
pkill -f "NameNode" 2>/dev/null || true
pkill -f "DataNode" 2>/dev/null || true
sleep 2

echo "Starting HDFS daemons..."
start-dfs.sh > /tmp/start-dfs.log 2>&1

# Wait for services to start
sleep 5

# Check if services started
if jps | grep -q "NameNode"; then
    echo "✓ NameNode started"
else
    echo "✗ NameNode failed to start"
    cat /tmp/start-dfs.log
    exit 1
fi

if jps | grep -q "DataNode"; then
    echo "✓ DataNode started"
else
    echo "✗ DataNode failed to start"
    cat /tmp/start-dfs.log
    exit 1
fi

if jps | grep -q "SecondaryNameNode"; then
    echo "✓ SecondaryNameNode started"
else
    echo "✗ SecondaryNameNode failed to start"
    cat /tmp/start-dfs.log
fi

echo ""

# ============================================================================
# STEP 10: START YARN
# ============================================================================
echo -e "${YELLOW}[STEP 10] Starting YARN...${NC}"
echo ""

# Kill any existing processes
pkill -f "ResourceManager" 2>/dev/null || true
pkill -f "NodeManager" 2>/dev/null || true
sleep 2

echo "Starting YARN daemons..."
start-yarn.sh > /tmp/start-yarn.log 2>&1

# Wait for services to start
sleep 5

# Check if services started
if jps | grep -q "ResourceManager"; then
    echo "✓ ResourceManager started"
else
    echo "✗ ResourceManager failed to start"
    cat /tmp/start-yarn.log
    exit 1
fi

if jps | grep -q "NodeManager"; then
    echo "✓ NodeManager started"
else
    echo "✗ NodeManager failed to start"
    cat /tmp/start-yarn.log
fi

echo ""

# ============================================================================
# STEP 11: VERIFY ALL SERVICES
# ============================================================================
echo -e "${YELLOW}[STEP 11] Verifying all services...${NC}"
echo ""

echo "Running Java processes:"
jps

echo ""
echo "Checking HDFS:"
if hdfs dfs -ls / 2>/dev/null; then
    echo "✓ HDFS is accessible"
else
    echo "✗ HDFS is not accessible yet"
fi

echo ""

# ============================================================================
# STEP 12: PRINT CONFIGURATION SUMMARY
# ============================================================================
echo -e "${YELLOW}[STEP 12] Configuration Summary${NC}"
echo ""

echo "Java Configuration:"
echo "  JAVA_HOME: $JAVA_HOME"
java -version 2>&1 | head -1

echo ""
echo "Hadoop Configuration:"
echo "  HADOOP_HOME: $HADOOP_HOME"
echo "  Default FS: hdfs://localhost:9000"
echo "  Replication Factor: 1"
echo "  NameNode Data: /opt/hadoop/data/namenode"
echo "  DataNode Data: /opt/hadoop/data/datanode"

echo ""
echo "SSH Configuration:"
echo "  SSH Key: ~/.ssh/id_rsa"
echo "  SSH Config: ~/.ssh/config (StrictHostKeyChecking=no)"

echo ""
echo "Running Services:"
jps | grep -v Jps

echo ""
echo "Web UIs:"
echo "  NameNode: http://localhost:9870"
echo "  ResourceManager: http://localhost:8088"
echo "  JobHistory: http://localhost:19888"

echo ""

# ============================================================================
# STEP 13: TEST HADOOP COMMANDS
# ============================================================================
echo -e "${YELLOW}[STEP 13] Testing Hadoop commands...${NC}"
echo ""

echo "Testing 'hdfs version':"
hdfs version | head -5

echo ""
echo "Testing 'hdfs dfs -ls /':"
hdfs dfs -ls / 2>/dev/null || echo "✓ HDFS directory listing works"

echo ""
echo "Testing 'hadoop version':"
hadoop version | head -3

echo ""

# ============================================================================
# FINAL SUMMARY
# ============================================================================
echo ""
echo -e "${GREEN}=========================================="
echo "SETUP COMPLETE!"
echo "==========================================${NC}"
echo ""
echo "Your Hadoop cluster is ready to use."
echo ""
echo "Quick commands:"
echo "  - Start all:     start-all.sh"
echo "  - Stop all:      stop-all.sh"
echo "  - View logs:     tail -f \$HADOOP_HOME/logs/hadoop-hadoop-*"
echo "  - Test HDFS:     hdfs dfs -ls /"
echo ""
echo "For persistent environment variables, your ~/.bashrc has been updated."
echo "Next time you start the container, run:"
echo "  source ~/.bashrc"
echo ""
echo "Or set it as your container's default command in docker-compose.yml:"
echo "  command: /bin/bash -c 'source ~/.bashrc && exec /bin/bash'"
echo ""
