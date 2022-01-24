#!/bin/bash

set -eu

# Following information will be used to create CA and self-signed certificate
COUNTRY=$COUNTRY
STATE=$STATE
LOCATION=$LOCATION
O=$ORGANIZATION
OU=$ORGANIZATION_UNIT
DOMAIN_NAME=$DOMAIN_NAME
PASSWORD=secret@Password!
VALIDITY_IN_DAYS=3650

# Internally used
WORKING_DIR=kafka-ssl
KEYSTORE_FILENAME="keystore.jks"
TRUSTSTORE_FILENAME="truststore.jks"
COMMON_TRUSTSTORE_FILENAME=$WORKING_DIR/$TRUSTSTORE_FILENAME
CERT_SIGN_REQUEST_FILE="cert-sign-req-file"
CERT_SIGNED_FILE="cert-signed-file"

CA_KEY_FILE=$WORKING_DIR/ca.key
CA_CERT_FILE=$WORKING_DIR/ca.crt
CA_ALIAS="kafka-ca"

# Wildcard DNS is supported from JAVA 15 onward.
# https://bugs.openjdk.java.net/browse/JDK-8186143

# Update the path of keytool execution file
#KEYTOOL=/path/to/jdk-15.0.2/bin/keytool
#Default keytool on system
KEYTOOL=`which keytool`

setup() {
  echo "======================================================================================"
  echo "Welcome to Kafka SSL/TLS keystore and truststore generator script."
  echo "======================================================================================"
  echo
  echo "Delete old working directory."

  rm -rf $WORKING_DIR && mkdir $WORKING_DIR

  echo
  echo "Create serial number and database index files for OpenSSL config."

  echo 01 > $WORKING_DIR/serial.txt
  touch $WORKING_DIR/index.txt
}

generate_ca_and_truststore() {
  echo
  echo "======================================================================================"
  echo "Generate Certificate Authority (CA) private key and certificate."
  echo "This CA will be used to sign all certificates."
  echo "======================================================================================"
  echo

  # OpenSSL config file is needed. See https://kafka.apache.org/documentation/#security_ssl_ca
  openssl req \
    -config openssl-ca.cnf \
    -new \
    -newkey rsa:4096 \
    -days $VALIDITY_IN_DAYS \
    -x509 \
    -subj "/C=$COUNTRY/ST=$STATE/L=$LOCATION/O=$O/OU=$OU/CN=Kafka-Security-CA" \
    -keyout $CA_KEY_FILE \
    -out $CA_CERT_FILE \
    -nodes

  echo
  echo "======================================================================================"
  echo "Create a common truststore contains CA's certificate."
  echo "This truststore will be used by both client(s) and server(s)."
  echo "======================================================================================"
  echo

  $KEYTOOL -keystore $COMMON_TRUSTSTORE_FILENAME \
   -alias $CA_ALIAS \
   -import \
   -file $CA_CERT_FILE \
   -keypass $PASSWORD \
   -storepass $PASSWORD \
   -dname "C=$COUNTRY, ST=$STATE, L=$LOCATION, O=$O, OU=$OU, CN=Kafka-Security-CA" \
   -noprompt \
   -storetype pkcs12
}
### gen_keystore function to generate a common truststore file
### and keystore file for each server. Required paramenters are
### hostname (without domain name) and IP Address
gen_keystore() {
    HOSTNAME=$1
    HOST_IP_ADDR=$2

    echo
    echo "======================================================================================"
    echo "Generating keystore with regular cert. for host: $HOSTNAME, IP Address: $HOST_IP_ADDR"
    echo "======================================================================================"

    KEY_STORE="$WORKING_DIR/$HOSTNAME.$KEYSTORE_FILENAME"
    TRUSTSTORE="$WORKING_DIR/$HOSTNAME.$TRUSTSTORE_FILENAME"
    CSR_FILE="$WORKING_DIR/$HOSTNAME.$CERT_SIGN_REQUEST_FILE"
    SIGNED_CERT_FILE="$WORKING_DIR/$HOSTNAME.$CERT_SIGNED_FILE"

    if [ -z "$DOMAIN_NAME" ]; then
      FQDN=$HOSTNAME
    else
      FQDN="$HOSTNAME.$DOMAIN_NAME"
    fi

    KEY_ALIAS=$FQDN

    echo
    echo "1). Create keystore."
    echo
    $KEYTOOL -genkey \
            -keyalg RSA \
            -keysize 4096 \
            -alias $KEY_ALIAS \
            -keystore $KEY_STORE \
            -validity $VALIDITY_IN_DAYS \
            -storepass $PASSWORD \
            -keypass $PASSWORD \
            -noprompt \
            -ext SAN=DNS:$FQDN,IP:$HOST_IP_ADDR \
            -dname "C=$COUNTRY, ST=$STATE, L=$LOCATION, O=$O, OU=$OU, CN=$FQDN" \
            -storetype pkcs12

    echo
    echo "2). Create certificate signing request (CSR)."
    echo
    $KEYTOOL -keystore $KEY_STORE \
            -certreq \
            -alias $KEY_ALIAS \
            -file $CSR_FILE \
            -storepass $PASSWORD \
            -keypass $PASSWORD \
            -ext SAN=DNS:$FQDN,IP:$HOST_IP_ADDR

    echo
    echo "3). Sign and issue a certificate according to the CSR."
    echo

    # OpenSSL config file is needed. See https://kafka.apache.org/documentation/#security_ssl_ca
    yes | openssl ca -config openssl-ca.cnf \
            -policy signing_policy \
            -extensions signing_req \
            -out $SIGNED_CERT_FILE \
            -infiles $CSR_FILE

    echo
    echo "4). Import CA's certificate to keystore."
    echo
    $KEYTOOL -keystore $KEY_STORE \
            -alias $CA_ALIAS \
            -import \
            -file $CA_CERT_FILE \
            -keypass $PASSWORD \
            -storepass $PASSWORD \
            -noprompt

    echo
    echo "5). Import the signed certificate to keystore."
    echo
    $KEYTOOL -keystore $KEY_STORE \
            -alias $KEY_ALIAS \
            -import \
            -file $SIGNED_CERT_FILE \
            -keypass $PASSWORD \
            -storepass $PASSWORD \
            -noprompt

    # clean up
    rm -f $CSR_FILE $SIGNED_CERT_FILE
}

### gen_keystore_with_wildcard_cert function to generated common
### truststore file and common keystore file contains wildcard certificate
### that can be used by all servers

gen_keystore_with_wildcard_cert() {
    echo
    echo "======================================================================================"
    echo "Generating keystore with wildcard cert. for domain: $DOMAIN_NAME"
    echo "======================================================================================"

    KEY_STORE="$WORKING_DIR/$KEYSTORE_FILENAME"
    TRUSTSTORE="$WORKING_DIR/$TRUSTSTORE_FILENAME"
    CSR_FILE="$WORKING_DIR/$CERT_SIGN_REQUEST_FILE"
    SIGNED_CERT_FILE="$WORKING_DIR/$CERT_SIGNED_FILE"
    FQDN="*.$DOMAIN_NAME"
    KEY_ALIAS=$FQDN

    echo
    echo "1). Create keystore."
    echo
    $KEYTOOL -genkey \
            -keyalg RSA \
            -keysize 4096 \
            -alias $KEY_ALIAS \
            -keystore $KEY_STORE \
            -validity $VALIDITY_IN_DAYS \
            -storepass $PASSWORD \
            -keypass $PASSWORD \
            -noprompt \
            -ext SAN=DNS:$FQDN \
            -dname "C=$COUNTRY, ST=$STATE, L=$LOCATION, O=$O, OU=$OU, CN=$FQDN" \
            -storetype pkcs12

    echo
    echo "2). Create certificate signing request (CSR)."
    echo
    $KEYTOOL -keystore $KEY_STORE \
            -certreq \
            -alias $KEY_ALIAS \
            -file $CSR_FILE \
            -storepass $PASSWORD \
            -keypass $PASSWORD \
            -ext SAN=DNS:$FQDN

    echo
    echo "3). Sign and issue a certificate according to the CSR."
    echo

    # OpenSSL config file is needed. See https://kafka.apache.org/documentation/#security_ssl_ca
    yes | openssl ca -config openssl-ca.cnf \
            -policy signing_policy \
            -extensions signing_req \
            -out $SIGNED_CERT_FILE \
            -infiles $CSR_FILE

    echo
    echo "4). Import CA's certificate to keystore."
    echo
    $KEYTOOL -keystore $KEY_STORE \
            -alias $CA_ALIAS \
            -import \
            -file $CA_CERT_FILE \
            -keypass $PASSWORD \
            -storepass $PASSWORD \
            -noprompt

    echo
    echo "5). Import the signed certificate to keystore."
    echo
    $KEYTOOL -keystore $KEY_STORE \
            -alias $KEY_ALIAS \
            -import \
            -file $SIGNED_CERT_FILE \
            -keypass $PASSWORD \
            -storepass $PASSWORD \
            -noprompt

    # clean up
    rm -f $CSR_FILE $SIGNED_CERT_FILE
}

gen_single_host_keystore() {
  if [[ -z "$HOST_IP_LIST" ]]; then
    echo "HOST_IP_LIST variable is not defined. Please make sure you have set the variable before running this script."
    exit 1
  fi

  setup
  generate_ca_and_truststore

  HOST_IP_ITEMS=$(echo $HOST_IP_LIST | tr ";" " ")
  for HOST_IP_PAIR in $HOST_IP_ITEMS; do
    HOST_AND_IP=$(echo $HOST_IP_PAIR | tr ":" " ")
    gen_keystore $HOST_AND_IP
  done
}

gen_keystore_for_new_host() {
    if [ ! -f $WORKING_DIR/serial.txt ]; then
      echo 01 > $WORKING_DIR/serial.txt
    fi
    if [ ! -f $WORKING_DIR/index.txt ]; then
      touch $WORKING_DIR/index.txt
    fi
    gen_keystore $1 $2
}

cleanup() {
    echo
    echo "Clean up temporary files."
    rm -f $WORKING_DIR/*.pem
}

if [ $1 = "wildcard" ]; then
  setup
  generate_ca_and_truststore
  gen_keystore_with_wildcard_cert
  cleanup
elif [ $1 = "regular" ]; then
  gen_single_host_keystore
  cleanup
elif [ $1 = "newhost" ]; then
  gen_keystore_for_new_host $2 $3
  cleanup
else
  echo "Please specify a valid parameter either 'wildcard' or 'regular'"
fi
