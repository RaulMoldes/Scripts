# bin/bash


if [ $# -ne 1 ]; then
  echo "Uso: $0 <url> <cacert> <token>"
  exit 1
fi

# Dirección IP del servidor
SERVER_IP=$1

# Rango de puertos
START_PORT=1
END_PORT=65535

# Intervalo de tiempo entre cada intento de "knock" (en segundos)
DELAY=0.1

# Realizar el knock en todos los puertos en el rango
for PORT in $(seq $START_PORT $END_PORT); do
    echo "Knocking on port $PORT..."
    nc -z -w1 $SERVER_IP $PORT
    sleep $DELAY
done

echo "Knocking finalizado en todos los puertos"
