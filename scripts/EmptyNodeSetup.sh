#! /bin/bash
echo "Empty node setup"

sudo apt install jq wget -y

## create kafka conenct dependencies directory
sudo mkdir -p /kafka/connect/libs/
sudo mkdir -p /kafka/connect/scripts/
sudo mkdir -p /kafka/connect/tools/
sudo mkdir -p /kafka/connect/tools/libs/
sudo mkdir -p /kafka/connect/config/

export password='Sheng@88509317'
export clusterName=$(curl -u admin:$password -sS -G "http://headnodehost:8080/api/v1/clusters" | jq -r '.items[].Clusters.cluster_name')
export KAFKAZKHOSTS=$(curl -sS -u admin:$password -G https://$clusterName.azurehdinsight.net/api/v1/clusters/$clusterName/services/ZOOKEEPER/components/ZOOKEEPER_SERVER | jq -r '["\(.host_components[].HostRoles.host_name):2181"] | join(",")' | cut -d',' -f1,2);
export KAFKABROKERS=$(curl -sS -u admin:$password -G https://$clusterName.azurehdinsight.net/api/v1/clusters/$clusterName/services/KAFKA/components/KAFKA_BROKER | jq -r '["\(.host_components[].HostRoles.host_name):9092"] | join(",")' | cut -d',' -f1,2);

sudo bash -c 'echo $clusterName > /kafka/connect/scripts/test'

## install confluent hub client
cd /kafka/connect/tools/
sudo wget http://client.hub.confluent.io/confluent-hub-client-latest.tar.gz
sudo tar zxvf confluent-hub-client-latest.tar.gz
export PATH=$PATH:/kafka/connect/tools/bin

## configure connect-distributed.properties file
sudo bash -c 'cat << EOF > /kafka/connect/config/connect-distributed.properties
bootstrap.servers=${KAFKABROKERS}:9092
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

internal.key.converter=org.apache.kafka.connect.json.JsonConverter
internal.value.converter=org.apache.kafka.connect.json.JsonConverter
internal.key.converter.schemas.enable=false
internal.value.converter.schemas.enable=false

plugin.path=/kafka/connect/libs/
EOF'

sudo bash -c 'envsubst '${KAFKABROKERS}' < /kafka/connect/config/connect-distributed.properties > /kafka/connect/config/connect-distributed.properties'

# download kafka connectors denpendencies
# sudo confluent-hub install confluentinc/kafka-connect-azure-data-lake-gen2-storage:latest --component-dir /kafka/connect/tools/libs/ --worker-configs /kafka/connect/config/connect-distributed.properties

# setup configurations in connect-distributed.properties

# launch kafka connect cluster bin/connect-distributed.sh -daemon conf/connect-distributed.properties