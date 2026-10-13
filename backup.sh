#!/bin/bash
BACKUP_DATE=$(date '+%Y%m%d_%H%M')

CONFIG_BACKUP_FILENAME="${BACKUP_DATE}__config.tar.gz"
CONFIG_BACKUP_FILEPATH="$PWD/backups/$CONFIG_BACKUP_FILENAME"
echo -n "Creating config backup $CONFIG_BACKUP_FILEPATH ... " >&2

if sudo tar zcf "$CONFIG_BACKUP_FILEPATH" \
    --exclude='config/amd' \
    --exclude='config/deluge/archive/*' \
    --exclude='config/deluge/state/*' \
    --exclude='config/deluge/torrents/*' \
    --exclude='config/deluge/dht.state' \
    --exclude='config/kavita/covers/*' \
    --exclude='config/plex/Library/Application Support/Plex Media Server/Cache/*' \
    --exclude='config/plex/Library/Application Support/Plex Media Server/Crash Reports/*' \
    --exclude='config/plex/Library/Application Support/Plex Media Server/Diagnostics/*' \
    --exclude='config/plex/Library/Application Support/Plex Media Server/Logs/*' \
    --exclude='config/plex/Library/Application Support/Plex Media Server/Media/*' \
    --exclude='config/plex/Library/Application Support/Plex Media Server/Metadata/*' \
    --exclude='config/plex/Library/Application Support/Plex Media Server/Plug-in Support/Caches/*' \
    --exclude='config/*/Backups/*' \
    --exclude='config/*/backups/*' \
    --exclude='config/*/cache/*' \
    --exclude='config/*/logs/*' \
    --exclude='config/*/MediaCover/*' \
    --exclude='config/*/temp/*' \
    --exclude='config/*/*.bak' \
    --exclude='config/*/*.log' \
    --exclude='config/webrcade/*' \
    --exclude='desktop.ini' \
    --exclude='*~' \
    --exclude='*.bak' \
    --exclude='*.db-2*' \
    --exclude='*.git*' \
    --exclude='*.log*' \
    --exclude='*.pid' \
    --exclude='.DS_Store' \
    config/ .env \
; then
  echo "OK" >&2
else
  echo "ERR" >&2
fi

if [[ -f "$CONFIG_BACKUP_FILEPATH" ]]; then
  sudo chown "$(id -u):$(id -g)" "$CONFIG_BACKUP_FILEPATH"
fi

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
