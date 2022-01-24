#!/bin/bash

/opt/redhat-amq-streams/bin/kafka_exporter \
--kafka.version="2.8.0" \
--kafka.version="2.8.0" \
--kafka.server=kafka1.example.com:9092 \
--kafka.server=kafka2.example.com:9092 \
--kafka.server=kafka3.example.com:9092 \
--sasl.enabled=true \
--sasl.username="admin" \
--sasl.password="secret@Password!" \
--sasl.mechanism="PLAIN" \
--tls.enabled=true \
--tls.ca-file=ca.crt