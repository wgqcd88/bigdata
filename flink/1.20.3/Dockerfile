FROM flink:1.20.3-scala_2.12-java17
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 python3-pip && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    python --version && \
    rm -rf /var/lib/apt/lists/* && \
    pip3 install apache-flink==1.20.3
USER flink
RUN mkdir -p /opt/flink/plugins/azure-fs-hadoop/  && \
    cp /opt/flink/opt/flink-azure-fs-hadoop-1.20.3.jar /opt/flink/plugins/azure-fs-hadoop/ && \
    curl -o /opt/flink/lib/flink-connector-kafka-3.4.0-1.20.jar https://repo1.maven.org/maven2/org/apache/flink/flink-connector-kafka/3.4.0-1.20/flink-connector-kafka-3.4.0-1.20.jar

COPY com.github.azure.hadoop.custom.auth-1.3.jar /opt/flink/lib/com.github.azure.hadoop.custom.auth-1.3.jar
COPY com.github.azure.hadoop.custom.auth-1.3.jar /opt/flink/plugins/azure-fs-hadoop/com.github.azure.hadoop.custom.auth-1.3.jar