#!/bin/bash
set -e
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

docker-compose pull

docker-compose up -d --always-recreate-deps

docker images \
  | grep -E "^(?:$(sed -nE 's/ +image: ([^:]+)(:.*)?$/\1/p' docker-compose.yml \
  | perl -0777 -pe 's/\n(.)/|\1/g'))\b" \
  | grep '<none>' \
  | awk '{ print $3 }' \
  | xargs -r docker rmi

