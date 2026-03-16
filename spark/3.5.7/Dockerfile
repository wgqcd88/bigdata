FROM spark:3.5.7-java17
RUN rm -rf /opt/spark/jars/hadoop-client-api-3.3.4.jar /opt/spark/jars/hadoop-client-runtime-3.3.4.jar /opt/spark/jars/hadoop-yarn-server-web-proxy-3.3.4.jar && \
	curl -Lo /opt/spark/jars/hadoop-client-api-3.3.6.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-client-api/3.3.6/hadoop-client-api-3.3.6.jar && \
	curl -Lo /opt/spark/jars/hadoop-client-runtime-3.3.6.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-client-runtime/3.3.6/hadoop-client-runtime-3.3.6.jar && \
	curl -Lo /opt/spark/jars/hadoop-yarn-server-web-proxy-3.3.6.jar  https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-yarn-server-web-proxy/3.3.6/hadoop-yarn-server-web-proxy-3.3.6.jar
COPY com.github.azure.hadoop.custom.auth-1.3.jar /opt/spark/jars/com.github.azure.hadoop.custom.auth-1.3.jar
COPY hadoop-azure-v6-3.3.6.jar /opt/spark/jars/hadoop-azure-v6-3.3.6.jar