#!/bin/bash

set -o nounset \
    -o errexit \
#    -o verbose \
#    -o xtrace

# Discover true path of script
pushd $(dirname $0) > /dev/null 2>&1
SCRIPT_PATH=$PWD/$(basename $0)
popd > /dev/null 2>&1
SCRIPT_BASE=$(dirname ${SCRIPT_PATH})

echo "$SCRIPT_BASE"

CA_PATH="generated_ca"

CA_NAME="test-ca-1"
CA_DOMAIN="confluent.local"

# Cert details
orgunit=TEST
org=CODECENTRIC
locality=Karlsruhe
state=Baden-Wuerttemberg
country=DE

CA_SUBJ="/CN=ca1.${CA_DOMAIN}/OU=${orgunit}/O=${org}/L=${locality}/ST=${state}/C=${country}"
CA_PASS="codecentric"

VALIDIY=3650                  # certificate validity

KEYPASS="codecentric"
STOREPASS="codecentric"

PASS_CLIENT="codecentric"

CERTS_ARRAY=( "kafka-1" )

DEFAULT_PATH_CA="${SCRIPT_BASE}/${CA_PATH}"

mkdir -p "${DEFAULT_PATH_CA}"

# cleanup
find "${DEFAULT_PATH_CA}" -type f \( -name "*.crt" -o -name "*.key" \) -exec rm {} \;
find "${DEFAULT_PATH_CA}" -type f \( -name "*.jks" -o -name "*.csr" -o -name "*.srl" -o -name "*.req" -o -name "*.pem" -o -name "*.creds" \) -exec rm {} \;

# Generate CA key
openssl req \
      -new \
      -x509 \
      -keyout "${DEFAULT_PATH_CA}/${CA_NAME}.key" \
      -out "${DEFAULT_PATH_CA}/${CA_NAME}.crt" \
      -days ${VALIDIY} \
      -subj "${CA_SUBJ}" \
      -passin "pass:$CA_PASS" \
      -passout "pass:$CA_PASS"

cat "${DEFAULT_PATH_CA}/${CA_NAME}.crt" "${DEFAULT_PATH_CA}/${CA_NAME}.key" > "${DEFAULT_PATH_CA}/${CA_NAME}.pem"

# Generate Server Certificates ---------------------------------
for i in "${CERTS_ARRAY[@]}"
do
    echo "Generating certificates for $i"

    # Create keystores
    keytool -genkey \
            -noprompt \
            -alias $i \
            -dname "CN=$i, OU=${orgunit}, O=${org}, L=${locality}, ST=${state}, C=${country}" \
            -ext "SAN=dns:$i,dns:$i.${CA_DOMAIN},dns:localhost" \
            -keystore "${DEFAULT_PATH_CA}/kafka.$i.keystore.jks" \
            -keyalg RSA \
            -storepass "${STOREPASS}" \
            -keypass "${KEYPASS}"

    # Create the certificate signing request (CSR)
    keytool -keystore "${DEFAULT_PATH_CA}/kafka.$i.keystore.jks" \
            -alias $i \
            -certreq \
            -file "${DEFAULT_PATH_CA}/$i.csr" \
            -storepass "${STOREPASS}" \
            -keypass "${KEYPASS}" \
            -ext "SAN=dns:$i,dns:$i.${CA_DOMAIN},dns:localhost"

    # Sign the certificate with the certificate authority (CA)
    openssl x509 \
        -req \
        -CA "${DEFAULT_PATH_CA}/${CA_NAME}.crt" \
        -CAkey "${DEFAULT_PATH_CA}/${CA_NAME}.key" \
        -in "${DEFAULT_PATH_CA}/$i.csr" \
        -out "${DEFAULT_PATH_CA}/$i-ca1-signed.crt" \
        -days "${VALIDIY}" \
        -CAcreateserial \
        -passin "pass:${CA_PASS}" \
        -extensions v3_req \
        -extfile <(cat <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = $i

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $i
DNS.2 = $i.${CA_DOMAIN}
DNS.3 = localhost
EOF
)

    # Sign and import the CA certificate into the keystore
    keytool -import \
        -noprompt \
        -keystore "${DEFAULT_PATH_CA}/kafka.$i.keystore.jks" \
        -alias CARoot \
        -file "${DEFAULT_PATH_CA}/${CA_NAME}.crt" \
        -storepass "${STOREPASS}" \
        -keypass "${KEYPASS}"

    # keytool -list -v -keystore "${DEFAULT_PATH_CA}/kafka.$i.keystore.jks" -storepass ${STOREPASS}

    # Sign and import the host certificate into the keystore
    keytool -import \
        -noprompt \
        -keystore "${DEFAULT_PATH_CA}/kafka.$i.keystore.jks" \
        -alias $i \
        -file "${DEFAULT_PATH_CA}/$i-ca1-signed.crt" \
        -storepass "${STOREPASS}" \
        -keypass "${KEYPASS}" \
        -ext "SAN=dns:$i,dns:$i.${CA_DOMAIN},dns:localhost"

    # keytool -list -v -keystore "${DEFAULT_PATH_CA}/kafka.$i.keystore.jks" -storepass ${STOREPASS}

    # Create truststore and import the CA cert.
    keytool -import \
        -noprompt \
        -keystore ${DEFAULT_PATH_CA}/kafka.$i.truststore.jks \
        -alias CARoot \
        -file "${DEFAULT_PATH_CA}/${CA_NAME}.crt" \
        -storepass "${STOREPASS}" \
        -keypass "${KEYPASS}"

    echo "${KEYPASS}" > ${DEFAULT_PATH_CA}/${i}_sslkey_creds
    echo "${STOREPASS}" > ${DEFAULT_PATH_CA}/${i}_keystore_creds
    echo "${STOREPASS}" > ${DEFAULT_PATH_CA}/${i}_truststore_creds
    
    # cleanup
    find "${DEFAULT_PATH_CA}" -type f \( -name "$i-*.crt" -o -name "$i.csr" \) -exec rm {} \;
    
done



# Kafkacat
openssl genrsa \
    -des3 \
    -passout "pass:${PASS_CLIENT}" \
    -out "${DEFAULT_PATH_CA}/kafkacat.client.key" \
    1024

openssl req \
    -new \
    -key "${DEFAULT_PATH_CA}/kafkacat.client.key" \
    -out "${DEFAULT_PATH_CA}/kafkacat.client.req" \
    -subj "/CN=kafkacat.${CA_DOMAIN}/OU=${orgunit}/O=${org}/L=${locality}/ST=${state}/C=${country}" \
    -passin "pass:${PASS_CLIENT}" \
    -passout "pass:${PASS_CLIENT}"

openssl x509 \
    -req \
    -CA "${DEFAULT_PATH_CA}/${CA_NAME}.crt" \
    -CAkey "${DEFAULT_PATH_CA}/${CA_NAME}.key" \
    -in "${DEFAULT_PATH_CA}/kafkacat.client.req" \
    -out "${DEFAULT_PATH_CA}/kafkacat-ca1-signed.pem" \
    -days ${VALIDIY} \
    -CAcreateserial \
    -passin "pass:$CA_PASS"


cat << EOF > "${DEFAULT_PATH_CA}/kafkacat.conf"
security.protocol=SSL
ssl.key.location=/tmp/certs/kafkacat.client.key
ssl.key.password=${PASS_CLIENT}
ssl.certificate.location=/tmp/certs/kafkacat-ca1-signed.pem
ssl.ca.location=/tmp/certs/${CA_NAME}.pem
EOF

# cleanup
find "${DEFAULT_PATH_CA}" -type f \( -name "kafkacat.client.req" \) -exec rm {} \;
