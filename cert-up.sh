#!/bin/bash

# Script base path
BASE_ROOT=$(cd "$(dirname "$0")"; pwd)
DATE_TIME=$(date +%Y%m%d%H%M%S)
CRT_BASE_PATH="/usr/syno/etc/certificate"
ACME_BIN_PATH="${BASE_ROOT}/acme.sh"
TEMP_PATH="${BASE_ROOT}/temp"
CRT_PATH_NAME=$(cat "${CRT_BASE_PATH}/_archive/DEFAULT")
CRT_PATH="${CRT_BASE_PATH}/_archive/${CRT_PATH_NAME}"

# Function to check and install the latest acme.sh
installAcme () {
  echo "Checking and installing the latest version of acme.sh..."
  mkdir -p "${ACME_BIN_PATH}"
  if [ ! -f "${ACME_BIN_PATH}/acme.sh" ]; then
    echo "acme.sh not found. Installing..."
    if ! curl -s https://get.acme.sh | sh -s email=your_email@example.com --install-dir "${ACME_BIN_PATH}"; then
      echo "[ERROR] Failed to install acme.sh."
      exit 1
    fi
  else
    echo "acme.sh found. Checking for updates..."
    if ! "${ACME_BIN_PATH}/acme.sh" --upgrade --home "${ACME_BIN_PATH}"; then
      echo "[ERROR] Failed to update acme.sh."
      exit 1
    fi
  fi
  echo "acme.sh installation complete."
}

# Function to generate a certificate
generateCrt () {
  echo "Generating certificate..."
  cd "${BASE_ROOT}" || exit 1
  source ./config

  # Register ZeroSSL account if necessary
  if [ "${CERT_SERVER}" == "zerossl" ]; then
    echo "Registering ZeroSSL account..."
    "${ACME_BIN_PATH}/acme.sh" --register-account -m "${ACCOUNT_EMAIL}" --server zerossl
  fi

  # Issue the certificate
  "${ACME_BIN_PATH}/acme.sh" --force --issue --dns "${DNS}" --dnssleep "${DNS_SLEEP}" \
    -d "${DOMAIN}" -d "*.${DOMAIN}" --server "${CERT_SERVER}"

  # Install the certificate
  "${ACME_BIN_PATH}/acme.sh" --install-cert -d "${DOMAIN}" -d "*.${DOMAIN}" \
    --cert-file "${CRT_PATH}/cert.pem" \
    --key-file "${CRT_PATH}/privkey.pem" \
    --fullchain-file "${CRT_PATH}/fullchain.pem"

  # Check if the certificate was successfully generated
  if [ -s "${CRT_PATH}/cert.pem" ]; then
    echo "Certificate generated successfully."
    echo "Certificate path details:"
    echo "  Cert File: ${CRT_PATH}/cert.pem"
    echo "  Key File: ${CRT_PATH}/privkey.pem"
    echo "  Fullchain File: ${CRT_PATH}/fullchain.pem"
    # Log paths to a log file for other programs to read
    echo "Cert Path: ${CRT_PATH}/cert.pem" > ${BASE_ROOT}/cert_paths.log
    echo "Key Path: ${CRT_PATH}/privkey.pem" >> ${BASE_ROOT}/cert_paths.log
    echo "Fullchain Path: ${CRT_PATH}/fullchain.pem" >> ${BASE_ROOT}/cert_paths.log
  else
    echo "[ERROR] Certificate generation failed."
    exit 1
  fi
}

# Main update function
updateCrt () {
  echo "------ Begin Update Certificate ------"
  installAcme
  generateCrt
  echo "Certificate update complete."
}

case "$1" in
  update)
    echo "Starting certificate update..."
    updateCrt
    ;;
  *)
    echo "Usage: $0 {update}"
    exit 1
    ;;
esac
