#!/bin/bash

if [ ! -f /acme.sh/account.conf ]; then
  echo "Initializing acme.sh"

  if [[ "${ACME_SERVER}" == "zerossl" ]]; then
    echo "Registering account with zerossl"
      acme.sh --register-account --server zerossl \
        --eab-kid  "${ZEROSSL_EAB_KID}" \
        --eab-hmac-key "${ZEROSSL_EAB_HMAC_KEY}" \
        --accountemail "${ZEROSSL_EMAIL}"
  else
    exit 1
  fi

  echo "Issue cert"
  echo "DNS_API: ${DNS_API}"
  acme.sh --issue --dns "${DNS_API}" -d "${ACME_DOMAIN}" -d "*.${ACME_DOMAIN}" --server "${ACME_SERVER}"

  # Deploy to nginx
  echo "Deploying cert to nginx"
  export DEPLOY_DOCKER_CONTAINER_LABEL=sh.acme.autoload.domain=nginx.ryuugu.dev
  export DEPLOY_DOCKER_CONTAINER_KEY_FILE=/etc/nginx/ssl/ryuugu.dev/key.pem
  export DEPLOY_DOCKER_CONTAINER_CERT_FILE=/etc/nginx/ssl/ryuugu.dev/cert.pem
  export DEPLOY_DOCKER_CONTAINER_CA_FILE=/etc/nginx/ssl/ryuugu.dev/ca.pem
  export DEPLOY_DOCKER_CONTAINER_FULLCHAIN_FILE=/etc/nginx/ssl/ryuugu.dev/full.pem
  export DEPLOY_DOCKER_CONTAINER_RELOAD_CMD="nginx -s reload"

  echo "Deploying cert to vault"


  # Run the acme.sh deploy command
  acme.sh --deploy -d "${ACME_DOMAIN}" --deploy-hook docker
fi

echo 'Listing certs'
acme.sh --list

crond -n -s -m off
