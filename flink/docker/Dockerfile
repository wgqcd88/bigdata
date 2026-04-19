# ============================================================
# Multi-version Flink Docker Image
# ============================================================
# docker build -t flink:1.20.3 .
# docker build -t flink:1.20.3-nopy --build-arg INSTALL_PYTHON=false .
# docker build -t flink:1.20.3-lib  --build-arg AZURE_FS_TARGET=lib .
# docker build -t flink:1.19.1      --build-arg FLINK_VERSION=1.19.1 .
# ============================================================

ARG FLINK_VERSION=2.2.0
ARG SCALA_VERSION=2.12
ARG JAVA_VERSION=java17

FROM flink:${FLINK_VERSION}-scala_${SCALA_VERSION}-${JAVA_VERSION}

ARG FLINK_VERSION=2.2.0
ARG INSTALL_PYTHON=true
ARG PYFLINK_VERSION=""
ARG AZURE_FS_TARGET=plugin

LABEL flink.version="${FLINK_VERSION}" \
      python.enabled="${INSTALL_PYTHON}" \
      azure.fs.target="${AZURE_FS_TARGET}"

USER root
RUN set -eux; \
    if [ "${INSTALL_PYTHON}" = "true" ]; then \
        apt-get update && \
        apt-get install -y --no-install-recommends python3 python3-pip && \
        ln -sf /usr/bin/python3 /usr/bin/python && \
        python --version && \
        rm -rf /var/lib/apt/lists/* && \
        PIP_BREAK_SYSTEM_PACKAGES=1 \
          pip3 install --no-cache-dir \
          apache-flink==${PYFLINK_VERSION:-${FLINK_VERSION}}; \
    fi

USER flink
RUN set -eux; \
    case "${AZURE_FS_TARGET}" in \
        plugin|lib) ;; \
        *) echo "ERROR: AZURE_FS_TARGET must be plugin|lib (got '${AZURE_FS_TARGET}')" && exit 1 ;; \
    esac; \
    AZURE_JAR="/opt/flink/opt/flink-azure-fs-hadoop-${FLINK_VERSION}.jar"; \
    if [ "${AZURE_FS_TARGET}" = "plugin" ]; then \
        mkdir -p /opt/flink/plugins/azure-fs-hadoop/ && \
        cp "${AZURE_JAR}" /opt/flink/plugins/azure-fs-hadoop/; \
    else \
        cp "${AZURE_JAR}" /opt/flink/lib/; \
    fi

COPY --chown=flink:flink com.github.azure.hadoop.custom.auth-1.3.jar \
     /opt/flink/lib/com.github.azure.hadoop.custom.auth-1.3.jar
RUN if [ "${AZURE_FS_TARGET}" = "plugin" ]; then \
        mkdir -p /opt/flink/plugins/azure-fs-hadoop/ && \
        cp /opt/flink/lib/com.github.azure.hadoop.custom.auth-1.3.jar \
           /opt/flink/plugins/azure-fs-hadoop/; \
    fi
