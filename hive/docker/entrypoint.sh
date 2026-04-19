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