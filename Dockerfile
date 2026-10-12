FROM apache/hadoop:3.5.0

# Base image already runs as non-root; become root for package install/config
USER root

# Install OpenSSH server and utilities
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    openssh-server \
    openssh-client \
    vim \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Pre-create /run/sshd and set pid file so sshd can run as root (root must own it, 0755)
RUN mkdir -p /run/sshd && chmod 755 /run/sshd && \
    printf '\nPidFile /tmp/sshd.pid\n' >> /etc/ssh/sshd_config

# Set a default password so host can log in via ssh hadoop@localhost (workshop credential)
RUN echo 'hadoop:hadoop' | chpasswd

# Create hadoop user if it doesn't exist (it usually does in hadoop image)
RUN useradd -m -s /bin/bash hadoop 2>/dev/null || true

# Switch to hadoop user
USER hadoop
WORKDIR /home/hadoop

# Create SSH directory
RUN mkdir -p ~/.ssh && chmod 700 ~/.ssh

# Generate SSH keys for passwordless SSH (idempotent - base key may already exist)
RUN ( [ -f ~/.ssh/id_rsa ] || ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa ) && \
    cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys && \
    chmod 600 ~/.ssh/authorized_keys

# Configure SSH client
RUN cat > ~/.ssh/config << 'EOF'
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
    LogLevel=ERROR
EOF
RUN chmod 600 ~/.ssh/config

# Get Java path and set up environment
RUN JAVA_PATH=$(readlink -f $(which java)) && \
    JAVA_HOME=$(dirname $(dirname "$JAVA_PATH")) && \
    echo "export JAVA_HOME=$JAVA_HOME" >> ~/.bashrc && \
    echo "export HADOOP_HOME=/opt/hadoop" >> ~/.bashrc && \
    echo "export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin" >> ~/.bashrc

# Configure hadoop-env.sh
RUN JAVA_PATH=$(readlink -f $(which java)) && \
    JAVA_HOME=$(dirname $(dirname "$JAVA_PATH")) && \
    sed -i "1a export JAVA_HOME=$JAVA_HOME" /opt/hadoop/etc/hadoop/hadoop-env.sh && \
    echo 'export HADOOP_SSH_OPTS="-o StrictHostKeyChecking=no"' >> /opt/hadoop/etc/hadoop/hadoop-env.sh

# Configure Hadoop XML files for pseudo-distributed mode
RUN cat > /opt/hadoop/etc/hadoop/core-site.xml << 'EOF'
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

RUN cat > /opt/hadoop/etc/hadoop/hdfs-site.xml << 'EOF'
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

RUN cat > /opt/hadoop/etc/hadoop/mapred-site.xml << 'EOF'
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

RUN cat > /opt/hadoop/etc/hadoop/yarn-site.xml << 'EOF'
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

# Create data directories
RUN mkdir -p /opt/hadoop/tmp \
    /opt/hadoop/data/namenode \
    /opt/hadoop/data/datanode

# Copy setup scripts
USER root
COPY setup-hadoop.sh /home/hadoop/setup-hadoop.sh
COPY startup.sh /home/hadoop/startup.sh

RUN chmod +x /home/hadoop/setup-hadoop.sh /home/hadoop/startup.sh
USER hadoop

# Format NameNode (non-interactive)
RUN source ~/.bashrc && echo "Y" | hdfs namenode -format 2>&1 | grep -E "(Formatting|SHUTDOWN|completed)" || true

# Expose ports
# HDFS
EXPOSE 9000 50070 50470
# YARN
EXPOSE 8030 8031 8032 8033 8088
# Secondary NameNode
EXPOSE 9101
# Job History
EXPOSE 19888
# SSH
EXPOSE 22

# Set up entry point
CMD ["bash", "-c", "service ssh start && source ~/.bashrc && start-dfs.sh && start-yarn.sh && tail -f /dev/null"]
