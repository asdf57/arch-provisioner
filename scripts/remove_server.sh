
#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")"

function help() {
    echo "Usage: ./remove_server.sh <server name>"
    echo "Example: ./remove_server.sh beelink"
}

if [ "$#" -ne 1 ]; then
    help
    exit 1
fi

response=$(curl -s -w "%{http_code}" -X DELETE https://server-api.ryuugu.dev/entry/$1)
http_code="${response: -3}"
payload="${response%???}"

if [ "$http_code" -ne 200 ]; then
    echo "Failed to remove server: $payload"
    exit 1
fi

echo "Server removed successfully: $payload"
