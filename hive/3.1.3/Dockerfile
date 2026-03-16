FROM ubuntu AS builder
ARG HADOOP_VERSION=3.3.6
ARG HIVE_VERSION=3.1.3

ENV HADOOP_VERSION=${HADOOP_VERSION} HIVE_VERSION=${HIVE_VERSION}
RUN apt-get update && apt-get -y install wget curl tar
RUN  curl -o /opt/hadoop-${HADOOP_VERSION}.tar.gz "https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"
RUN  curl -o /opt/apache-hive-${HIVE_VERSION}-bin.tar.gz  "https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz"
RUN  curl -o /opt/postgresql.jar  "https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.8/postgresql-42.7.8.jar"
RUN  curl -o /opt/mysql-connector-j-8.4.0.jar  "https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.4.0/mysql-connector-j-8.4.0.jar"

RUN tar -xzvf /opt/hadoop-${HADOOP_VERSION}.tar.gz -C /opt/
RUN  rm -rf /opt/hadoop-${HADOOP_VERSION}/share/doc/*
RUN tar -xzvf /opt/apache-hive-${HIVE_VERSION}-bin.tar.gz -C /opt/

FROM eclipse-temurin:8-jre-jammy
ARG HADOOP_VERSION=3.3.6
ARG HIVE_VERSION=3.1.3
COPY --from=builder /opt/hadoop-$HADOOP_VERSION /opt/hadoop
COPY --from=builder /opt/apache-hive-${HIVE_VERSION}-bin /opt/hive
RUN rm -rf "/opt/hive/lib/postgresql-9.*.jar" "/opt/hadoop/share/hadoop/tools/lib/hadoop-azure-3.3.6.jar"
COPY --from=builder /opt/postgresql.jar /opt/hive/lib/postgresql.jar
COPY --from=builder /opt/mysql-connector-j-8.4.0.jar /opt/hive/lib/mysql-connector-j-8.4.0.jar
COPY com.github.azure.hadoop.custom.auth-1.3.jar /opt/hive/lib/com.github.azure.hadoop.custom.auth-1.3.jar
COPY hadoop-azure-v6-3.3.6.jar /opt/hadoop/share/hadoop/common/lib/hadoop-azure-3.3.6.jar
# Install dependencies
RUN set -ex; \
    apt-get update; \
    apt-get -y install procps lsof ; \
    rm -rf /var/lib/apt/lists/*
# Set necessary environment variables.
ENV HADOOP_HOME=/opt/hadoop \
    HIVE_HOME=/opt/hive \
    HIVE_VER=$HIVE_VERSION

ENV PATH=$HIVE_HOME/bin:$HADOOP_HOME/bin:$PATH
RUN cat > /entrypoint.sh <<'EOF'
#!/bin/bash
set -x
export HIVE_CONF_DIR=$HIVE_HOME/conf
if [ -d "${HIVE_CUSTOM_CONF_DIR:-}" ]; then
  find "${HIVE_CUSTOM_CONF_DIR}" -type f -exec \
    ln -sfn {} "${HIVE_CONF_DIR}"/ \;
  export HADOOP_CONF_DIR=$HIVE_CONF_DIR
fi
export HADOOP_CLIENT_OPTS="$HADOOP_CLIENT_OPTS -Xmx1G $SERVICE_OPTS"
export METASTORE_PORT=${METASTORE_PORT:-9083}
exec $HIVE_HOME/bin/hive --skiphadoopversion --skiphbasecp --service metastore
EOF
RUN chmod +x /entrypoint.sh
ARG UID=1000
RUN adduser --no-create-home --disabled-login --gecos "" --uid $UID hive && \
    chown hive /opt/hive && \
    chown hive /opt/hadoop && \
    chown hive /opt/hive/conf && \
    mkdir -p /opt/hive/data/warehouse && \
    chown hive /opt/hive/data/warehouse


USER hive
WORKDIR /opt/hive
EXPOSE  9083
ENTRYPOINT ["bash", "-c", "/entrypoint.sh"]