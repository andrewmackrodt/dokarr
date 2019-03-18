#!/bin/bash

# source environment variables
. /var/lib/boot2docker/.env

COMPOSE_VERSION=${COMPOSE_VERSION:-1.23.2}

docker pull docker/compose:$COMPOSE_VERSION

echo '#!/bin/bash

docker run --rm -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -v "$PWD:$PWD" \
    -w "$PWD" \
    docker/compose:'$COMPOSE_VERSION' "$@"

' > /usr/local/bin/docker-compose

chmod +x /usr/local/bin/docker-compose
