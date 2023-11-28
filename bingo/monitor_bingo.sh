#!/bin/bash

SERVICE_URL="http://localhost:15466/ping"

COMMAND_TO_EXECUTE="sudo systemctl restart bingo"

CHECK_INTERVAL=31

check_service() {
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $SERVICE_URL)
    if [ "$RESPONSE" != "200" ]; then
        echo "Service is not healthy. Executing command..."
        eval $COMMAND_TO_EXECUTE
    fi
}

while true; do
    check_service
    sleep $CHECK_INTERVAL
done