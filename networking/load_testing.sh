# !/bin/bash
## SCRIPT PARA HACERLE LOAD TESTING A UN SERVIDOR

if [ $# -ne 3 ]; then
  echo "Uso: $0 <url> <cacert> <token>"
  exit 1
fi

##!/bin/bash

#define variables
$URL=$1
$CACERT=$2
$TOKEN=$3



set -x # Ejecutar en modo debug
DURATION=60 # Durante cuanto tiempo aplicar carga
TPS=20 # Número de peticiones por segundo
end=$((SECONDS+$DURATION))
#Iniciar carga
while [ $SECONDS -lt $end ];
do
        for ((i=1;i<=$TPS;i++)); do
                curl -X POST <$URL> -H 'Accept: application/json' -H 'Authorization: Bearer $TOKEN' -H 'Content-Type: application/json' -d '{}' --cacert $CACERT -o /dev/null -s -w '%{time_starttransfer}\n' >> response-times.log &
        done
        sleep 1
done
wait

echo "Load test has been completed"