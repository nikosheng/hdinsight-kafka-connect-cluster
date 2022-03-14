#! /bin/bash

##Install dependencies
sudo apt-get update -y
sudo apt-get install \
curl \
wget \
jq \
lsb-release -y

## create kafka conenct dependencies directory
sudo mkdir -p /kafka/connect/libs/
sudo mkdir -p /kafka/connect/scripts/
sudo mkdir -p /kafka/connect/tools/
sudo mkdir -p /kafka/connect/tools/libs/
sudo mkdir -p /kafka/connect/config/
sudo chmod 777 /kafka/connect

## predefine system variables
password='xxxxxx'
clusterName=$(curl -u admin:$password -sS -G "http://headnodehost:8080/api/v1/clusters" | jq -r '.items[].Clusters.cluster_name')
KAFKAZKHOSTS=$(curl -sS -u admin:$password -G https://$clusterName.azurehdinsight.net/api/v1/clusters/$clusterName/services/ZOOKEEPER/components/ZOOKEEPER_SERVER | jq -r '["\(.host_components[].HostRoles.host_name):2181"] | join(",")' | cut -d',' -f1,2);
KAFKABROKERS=$(curl -sS -u admin:$password -G https://$clusterName.azurehdinsight.net/api/v1/clusters/$clusterName/services/KAFKA/components/KAFKA_BROKER | jq -r '["\(.host_components[].HostRoles.host_name):9092"] | join(",")' | cut -d',' -f1,2);

## create kafka topics required by kafka connect distributed mode, please do not reduce the partition numbers
/usr/hdp/current/kafka-broker/bin/kafka-topics.sh --create --replication-factor 3 --partitions 8 --topic connect-offsets --zookeeper $KAFKAZKHOSTS
/usr/hdp/current/kafka-broker/bin/kafka-topics.sh --create --replication-factor 3 --partitions 25 --topic connect-configs --zookeeper $KAFKAZKHOSTS
/usr/hdp/current/kafka-broker/bin/kafka-topics.sh --create --replication-factor 3 --partitions 8 --topic connect-status --zookeeper $KAFKAZKHOSTS

## install confluent hub client
cd /kafka/connect/tools/
sudo wget http://client.hub.confluent.io/confluent-hub-client-latest.tar.gz
sudo tar zxvf confluent-hub-client-latest.tar.gz
sudo bash -c "echo 'export KAFKAZKHOSTS=$KAFKAZKHOSTS' >> /etc/profile"
sudo bash -c "echo 'export KAFKABROKERS=$KAFKABROKERS' >> /etc/profile"
sudo bash -c "source /etc/profile"

## configure connect-distributed.properties file
sudo bash -c 'cat << EOF > /kafka/connect/config/connect-distributed.properties
group.id=connect-cluster-group

# connect internal topic names, auto-created if not exists
config.storage.topic=connect-configs
offset.storage.topic=connect-offsets
status.storage.topic=connect-status

# internal topic replication factors - auto 3x replication in Azure Storage
config.storage.replication.factor=1
offset.storage.replication.factor=1
status.storage.replication.factor=1

offset.flush.interval.ms=10000

key.converter=org.apache.kafka.connect.storage.StringConverter
value.converter=org.apache.kafka.connect.json.JsonConverter
internal.key.converter=org.apache.kafka.connect.json.JsonConverter
internal.value.converter=org.apache.kafka.connect.json.JsonConverter
internal.key.converter.schemas.enable=false
internal.value.converter.schemas.enable=false

plugin.path=/kafka/connect/libs/
EOF'

# setup configurations in connect-distributed.properties
sudo bash -c "echo 'bootstrap.servers=${KAFKABROKERS}' >> /kafka/connect/config/connect-distributed.properties"
# sudo bash -c 'envsubst '${KAFKABROKERS}' < /kafka/connect/config/connect-distributed.properties.template > /kafka/connect/config/connect-distributed.properties'

# download kafka connectors denpendencies
sudo bash -c "/kafka/connect/tools/bin/confluent-hub install --no-prompt confluentinc/kafka-connect-azure-data-lake-gen2-storage:latest --component-dir /kafka/connect/libs/ --worker-configs /kafka/connect/config/connect-distributed.properties"
sudo bash -c "/kafka/connect/tools/bin/confluent-hub install --no-prompt debezium/debezium-connector-mysql:latest --component-dir /kafka/connect/libs/ --worker-configs /kafka/connect/config/connect-distributed.properties"
sudo bash -c "/kafka/connect/tools/bin/confluent-hub install --no-prompt confluentinc/kafka-connect-avro-converter:7.0.1 --component-dir /kafka/connect/libs/ --worker-configs /kafka/connect/config/connect-distributed.properties"

# launch kafka connect cluster bin/connect-distributed.sh -daemon conf/connect-distributed.properties
sudo bash -c "/usr/hdp/current/kafka-broker/bin/connect-distributed.sh -daemon /kafka/connect/config/connect-distributed.properties"