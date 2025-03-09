FROM hashicorp/vault:1.18

RUN apk add --no-cache curl jq

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
COPY vault.hcl /vault.hcl

ENTRYPOINT ["/entrypoint.sh"]
