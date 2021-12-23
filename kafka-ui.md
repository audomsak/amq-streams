# UI for Apache Kafka up and running

Red Hat® AMQ Streams, by default, doesn't have a web console for admin or users to manage, browse, monitor etc. the cluster.
UI for Apache Kafka is a free, open-source web UI to monitor and manage Apache Kafka clusters. Please visit project's [GitHub](https://github.com/provectus/kafka-ui) for more details.

## Prerequisites

- Podman - See: Podman installation [instructions](https://podman.io/getting-started/installation) for other OS.

    Podman installation for RHEL7.

    ```sh
    sudo subscription-manager repos --enable=rhel-7-server-extras-rpms
    sudo yum -y install podman
    ```

    Podman installation for RHEL8.

    ```sh
    sudo yum module enable -y container-tools:rhel8
    sudo yum module install -y container-tools:rhel8
    ```

- Rootless environment - See: [Basic Setup and Use of Podman in a Rootless environment tutorial](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md).

**_Note:_** Docker can be used instead of Podman if needed.

## Run UI for Apache Kafka

Once you've finished the AMQ Streams cluster setup, you can run UI for Apache Kafka as a container and connect it to the cluster using the command below. or Use the [kafka-ui.sh](kafka-ui.sh) script.

However, you need to update the parameters and/or environment variables with the correct values before running this command as well as the script. Further configuration with environment variables - [see environment variables](https://github.com/provectus/kafka-ui#env_variables).

Once you've run the command, visit [http://localhost:8080](http://localhost:8080) if you run on a local host and didn't change host port mapping (`-p` parammeter) in the command. Otherwise, change the URL to the right hostname/domain and port number.

Here is a command to run UI for Apache Kafka as container.

- `-p` - Host port mapping. You can change or leave it as it.
- `-v` - Bind mount path to a truststore.jks file.
- `SPRING_SECURITY_USER_NAME` - Default username for login to web console.
- `SPRING_SECURITY_USER_PASSWORD` - Default password for login to web console.
- `KAFKA_CLUSTERS_0_ZOOKEEPER` - Zookeeper host and port.
- `KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS` - A list of Kafka broker and port.

Feel free to update the rest of environment variable values are based on cluster configurations.

```sh
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
-e KAFKA_CLUSTERS_0_PROPERTIES_SSL_TRUSTSTORE_LOCATION=/ssl/truststore.jks \
-e KAFKA_CLUSTERS_0_PROPERTIES_SSL_TRUSTSTORE_PASSWORD=secret@Password! \
-e KAFKA_CLUSTERS_0_PROPERTIES_SASL_JAAS_CONFIG="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"admin\" password=\"secret@Password!\";" \
docker.io/provectuslabs/kafka-ui:latest

```
