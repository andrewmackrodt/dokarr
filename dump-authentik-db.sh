#!/bin/bash
BACKUP_DATE=$(date '+%Y%m%d_%H%M')

AUTHENTIK_DB_BACKUP_FILENAME="${BACKUP_DATE}__authentik.sql.gz"
AUTHENTIK_DB_BACKUP_FILEPATH="$PWD/backups/$AUTHENTIK_DB_BACKUP_FILENAME"
echo -n "Creating authentik db backup $AUTHENTIK_DB_BACKUP_FILEPATH ... " >&2

if docker compose exec -T authentik_postgresql sh -c 'pg_dumpall -U "$POSTGRES_USER"' \
 | pigz --best >"$AUTHENTIK_DB_BACKUP_FILEPATH" \
; then
  echo "OK" >&2
else
  echo "ERR" >&2
fi
