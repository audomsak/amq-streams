#!/bin/bash

podman run --rm -d -p 8080:8080 \
--name kafka-ui \
-v /path/to/truststore.jks:/ssl/truststore.jks:Z \
-e AUTH_ENABLED=true \
-e SPRING_SECURITY_USER_NAME=admin \
-e SPRING_SECURITY_USER_PASSWORD=secret \
-e KAFKA_CLUSTERS_0_NAME=redhat-amq-streams \
-e KAFKA_CLUSTERS_0_ZOOKEEPER=zookeeper1.example.com:2181 \
-e KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS=kafka1.example.com:9095,kafka2.example.com:9095,kafka3.example.com:9095 \
-e KAFKA_CLUSTERS_0_PROPERTIES_SECURITY_PROTOCOL=SASL_SSL \
-e KAFKA_CLUSTERS_0_PROPERTIES_SASL_MECHANISM=PLAIN \
-e KAFKA_CLUSTERS_0_PROPERTIES_SSL_TRUSTSTORE_LOCATION=/kafka-ssl/truststore.jks \
-e KAFKA_CLUSTERS_0_PROPERTIES_SSL_TRUSTSTORE_PASSWORD=secret \
-e KAFKA_CLUSTERS_0_PROPERTIES_SASL_JAAS_CONFIG="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"admin\" password=\"secret\";" \
docker.io/provectuslabs/kafka-ui:latest
