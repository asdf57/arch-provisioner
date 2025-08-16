
#!/bin/bash

set -euo pipefail

# Initialize a server
# Usage: ./add_server.sh <server schema file>
# Example: ./add_server.sh beelink.json

# Server functionalities
# - Add server
# - Remove server




cd "$(dirname "$0")"

function help() {
    echo "Usage: ./add_server.sh <server schema file>"
    echo "Example: ./add_server.sh beelink.json"
}

if [ "$#" -ne 1 ]; then
    help
    exit 1
fi

if [ ! -f "../schemas/$1" ]; then
    echo "Schema file $1 not found!"
    exit 1
fi

file_path="../schemas/$1"

server_name=$(jq -r '.name' $file_path)

echo "Found server with name: $server_name"

response=$(curl -s -w "%{http_code}" -X POST -H "Content-Type: application/json" -H 'accept: application/json' -d @$file_path https://server-api.ryuugu.dev/entry/)
http_code="${response: -3}"
payload="${response%???}"

if [ "$http_code" -ne 200 ]; then
    echo "Failed to add server ($http_code): $payload"
    exit 1
fi

echo "Server added successfully: $payload"
