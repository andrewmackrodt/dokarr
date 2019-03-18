#!/bin/bash

cd /var/lib/boot2docker

# source environment variables
. "$PWD/.env"

# dockerd config
cat << 'EOF' > etc/docker/daemon.json
{
    "userland-proxy": false
}
EOF
chmod 0600 etc/docker/daemon.json

# harden ssh config
sed -i -E 's/^#?PasswordAuthentication .+/PasswordAuthentication no/' ssh/sshd_config
sed -i -E 's/^#?PermitRootLogin .+/PermitRootLogin no/' ssh/sshd_config

# install packages for cifs mounts
mkdir .tcecache 2>/dev/null
chown docker:root .tcecache
chmod 0775 .tcecache
mount --bind .tcecache /tmp/tce/optional
sudo -u docker tce-load -w cifs-utils samba-libs
sudo -u docker tce-load -i cifs-utils samba-libs

# install other packages
sudo -u docker tce-load -w htop iftop libpcap
sudo -u docker tce-load -i htop iftop libpcap

# create cifs credentials file
echo "username=$CIFS_USERNAME
password=$CIFS_PASSWORD
" > .smbcredentials
chmod 0600 .smbcredentials

# mount the cifs shares
DOCKER_HOST=$(ip route | awk '$1 == "default" { print $3 }' | head -n1)
CIFS_VERSION="${CIFS_VERSION:-2.0}"
CIFS_OPTS="vers=$CIFS_VERSION,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,noperm,nobrl,mfsymlinks,credentials=/var/lib/boot2docker/.smbcredentials"
if [[ "${CIFS_EXTRA_OPTS:-}" != "" ]]; then
    CIFS_OPTS="$CIFS_OPTS,$CIFS_EXTRA_OPTS"
fi

mkdir -p $SHARE_PATH

for i in $(seq 1 5); do
    mount -t cifs -o "$CIFS_OPTS" "//$DOCKER_HOST/dokarr" "$SHARE_PATH"
    if [[ $? == 0 ]]; then
        break
    fi
    sleep 1
done

# disable LookupCache if cache=none
if $(echo "$CIFS_OPTS" | grep -q 'cache=none'); then
    echo 0 > /proc/fs/cifs/LookupCacheEnabled
fi

# personalize userdata, e.g. add extra ssh keys
if [[ ! -f userdata.orig.tar ]]; then
    mv userdata.tar userdata.orig.tar
fi

# extract userdata
mkdir userdata
tar xf userdata.orig.tar -C userdata 2>/dev/null
cd userdata

# update authorized_keys
cd .ssh
rm authorized_keys2
ln -s authorized_keys authorized_keys2
for i in $(seq 0 4); do
    SSH_PUBLIC_KEY_VAR="SSH_PUBLIC_KEY_$i"
    if [[ "${!SSH_PUBLIC_KEY_VAR}" != "" ]]; then
        echo "${!SSH_PUBLIC_KEY_VAR}" >> authorized_keys
    fi
done
cd ..

# create the new archive
echo -e "source /usr/local/etc/bashrc\nsource .ashrc" > .bashrc
find . -mindepth 1 -maxdepth 1 | tar cf ../userdata.tar -T -
cd ..
rm -rf userdata
chown docker:staff userdata.tar
