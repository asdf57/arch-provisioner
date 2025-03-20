
#!/bin/bash

# Initialize a server
# Usage: ./add_server.sh <server schema file>
# Example: ./add_server.sh beelink.json

function help() {
    echo "Usage: ./add_server.sh <server schema file>"
    echo "Example: ./add_server.sh beelink.json"
}

if [ "$#" -ne 1 ]; then
    help
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "Schema file $1 not found!"
    exit 1
fi

response=$(curl -s -w "%{http_code}" -X POST -H "Content-Type: application/json" -d @$1 https://server-api.ryuugu.dev/entry)
http_code="${response: -3}"
payload="${response%???}"

if [ "$http_code" -ne 200 ]; then
    echo "Failed to add server: $payload"
    exit 1
fi

echo "Server added successfully: $payload"
