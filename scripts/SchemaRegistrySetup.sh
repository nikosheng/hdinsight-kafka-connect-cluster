#!/bin/bash

##curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
sudo apt-get update -y
sudo apt-get install \
ca-certificates \
curl \
gnupg \
lsb-release -y

##Add Docker’s official GPG key:
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

##Use the following command to set up the stable repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

##Install Docker Engine
sudo apt-get update -y
sudo apt-get install docker-ce docker-ce-cli containerd.io -y

##Apply current use to group docker
sudo usermod -aG docker ${USER}
sudo newgrp docker
sudo systemctl restart docker

##Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

##Create schema registry docker compose launch script
sudo mkdir -p /docker/script/
cd /docker/script/
sudo bash -c "cat << EOF > /docker/script/docker-compose.yaml
version: '3.8'
services:
  schema-registry:
    image: confluentinc/cp-schema-registry
    container_name: schema-registry
    ports:
      - 8181:8181
      - 8081:8081
    environment:
      - SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS=wn0-hdidev.5sygq4uwc1aulcrssdbuu13j3d.bx.internal.cloudapp.net:9092,wn1-hdidev.5sygq4uwc1aulcrssdbuu13j3d.bx.internal.cloudapp.net:9092
      - SCHEMA_REGISTRY_KAFKASTORE_CONNECTION_URL=zk0-hdidev.5sygq4uwc1aulcrssdbuu13j3d.bx.internal.cloudapp.net:2181,zk4-hdidev.5sygq4uwc1aulcrssdbuu13j3d.bx.internal.cloudapp.net:2181
      - SCHEMA_REGISTRY_HOST_NAME=schema-registry
      - SCHEMA_REGISTRY_LISTENERS=http://schema-registry:8081
      - SCHEMA_REGISTRY_ACCESS_CONTROL_ALLOW_METHODS=GET,POST,PUT,OPTIONS
      - SCHEMA_REGISTRY_ACCESS_CONTROL_ALLOW_ORIGIN=*

  schema-registry-ui:
    image: landoop/schema-registry-ui
    depends_on:
      - schema-registry
    ports:
      - 8000:8000
    environment:
      - SCHEMAREGISTRY_URL=http://schema-registry:8081
      - PROXY=true
    links:
      - schema-registry

  mysql:
    image: mysql:5.7
    container_name: mysql
    ports:
      - 3306:3306
    environment:
     - MYSQL_ROOT_PASSWORD=debezium
     - MYSQL_USER=mysqluser
     - MYSQL_PASSWORD=mysqlpw
EOF"

sudo docker-compose -f docker-compose.yaml up -d