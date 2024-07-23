#!/bin/bash
set -eo pipefail

log() {
  echo "$@" 1>&2
}

print_error() {
  echo "$@" 1>&2
  exit 1
}

print_usage() {
  print_error "Usage: gen-ssl-cert-key <fqdn> <output-dir>"
}

gen_cert_subject() {
  local fqdn="$1"
  [[ "${fqdn}" != "" ]] || print_error "FQDN cannot be blank"
  echo "/C=XX/ST=X/O=X/localityName=X/CN=${fqdn}/organizationalUnitName=X/emailAddress=X/"
}

main() {
  local fqdn="$1"
  local sslDir="$2"
  local cnfDir="$3"
  local srvType="$4"
  local ubuntuVersion="$5"
  [[ "${fqdn}" != "" ]] || print_usage
  [[ -d "${sslDir}" ]] || print_error "Directory does not exist: ${sslDir}"

  local caCertFile="${sslDir}/ca.pem"
  local caKeyFile="${sslDir}/ca.key"
  local certFile="${sslDir}/server.pem"
  local keyFile="${sslDir}/server.key"
  local pubkeyFile="${sslDir}/public.key"
  local serverReqFile="${sslDir}/server-req.pem"

  local clientReqFile="${sslDir}/client-req.pem"
  local clientCertFile="${sslDir}/client.pem"
  local clientKeyFile="${sslDir}/client.key"

  local pcks12FullKeystoreFile="${sslDir}/fullclient-keystore.p12"
  local clientReqFile=$(mktemp)

  log "Generating CA key"
  openssl genrsa -out "${caKeyFile}" 2048

  log "Generating CA certificate"
  openssl req -new -x509 -nodes \
   -subj "$(gen_cert_subject ca.example.com)" \
   -key "${caKeyFile}" \
   -out "${caCertFile}"

  log "Generate the private key and certificate request"
  openssl req -newkey rsa:2048 -nodes \
   -subj "$(gen_cert_subject "$fqdn")" \
   -keyout  "${keyFile}" \
   -out "${serverReqFile}"

  log "Generating public key"
  openssl rsa -in "${keyFile}" -pubout -out "${pubkeyFile}"

  log "Generate the X509 certificate for the server"
  openssl x509 -req -set_serial 01 \
     -in "${serverReqFile}" \
     -out "${certFile}" \
     -CA "${caCertFile}" \
     -CAkey "${caKeyFile}"


  log "Generate the client private key and certificate request:"
  openssl req -newkey rsa:2048 -nodes \
   -subj "$(gen_cert_subject "$fqdn")" \
   -keyout  "${clientKeyFile}" \
   -out "${clientReqFile}"

  log "Generate the X509 certificate for the server"
  openssl x509 -req -set_serial 01 \
     -in "${clientReqFile}" \
     -out "${clientCertFile}" \
     -CA "${caCertFile}" \
     -CAkey "${caKeyFile}" -days 365

  # Now generate a full keystore with the client cert & key + trust certificates
  log "Generating full client keystore"
  if [[ $ubuntuVersion > '20' ]] ; then
    openssl pkcs12 -export -in "${clientCertFile}" -inkey "${clientKeyFile}" -out "${pcks12FullKeystoreFile}" \
    -name "mysqlAlias" -passout pass:kspass -legacy
  else
    openssl pkcs12 -export -in "${clientCertFile}" -inkey "${clientKeyFile}" -out "${pcks12FullKeystoreFile}" \
    -name "mysqlAlias" -passout pass:kspass
  fi

  # Clean up CSR file:
  rm "$clientReqFile"

  log "Generated key file and certificate in: ${sslDir}"
}

main "$@"
