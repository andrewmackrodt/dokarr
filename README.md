# dockarr

Dockerized media management with letsencrypt support.

### Services

| - | description
|---------------------------------------------------|----------
| [![plex][plex-logo]][plex-link]                   | **Plex** - organize all of your personal media so you can enjoy it no matter where you are.
| [![tautulli][tautulli-logo]][tautulli-link]       | **Tautulli** - monitoring and tracking tool for Plex Media Server.
| [![sonarr][sonarr-logo]][sonarr-link]             | **Sonarr** - smart PVR for newsgroup and bittorrent users.
| [![radarr][radarr-logo]][radarr-link]             | **Radarr** - a fork of Sonarr to work with movies à la Couchpotato.
| [![lidarr][lidarr-logo]][lidarr-link]             | **Lidarr** - looks and smells like Sonarr but made for music.
| [![jackett][jackett-logo]][jackett-link]          | **Jackett** - API Support for your favorite torrent trackers. 
| [![nzbget][nzbget-logo]][nzbget-link]             | **NZBGet** - an efficient Usenet Downloader.
| [![deluge][deluge-logo]][deluge-link]             | **Deluge** - a lightweight, Free Software, cross-platform BitTorrent client.
| [![private internet access][pia-logo]][pia-link]  | **Private Internet Access** - VPN service providing an anonymous IP.
| [![tiny-proxy][tiny-proxy-logo]][tiny-proxy-link] | **Tinyproxy** - provides an http proxy for the PIA VPN connection.
| [![portainer][portainer-logo]][portainer-link]    | **Portainer** - simple management UI for Docker.


[plex-link]: https://hub.docker.com/r/linuxserver/plex
[plex-logo]: docs/images/plex.png
[tautulli-link]: https://hub.docker.com/r/linuxserver/tautulli
[tautulli-logo]: docs/images/tautulli.png
[sonarr-link]: https://hub.docker.com/r/linuxserver/sonarr
[sonarr-logo]: docs/images/sonarr.png
[radarr-link]: https://hub.docker.com/r/linuxserver/radarr
[radarr-logo]: docs/images/radarr.png
[lidarr-link]: https://hub.docker.com/r/linuxserver/lidarr
[lidarr-logo]: docs/images/lidarr.png
[nzbget-link]: https://hub.docker.com/r/linuxserver/nzbget
[nzbget-logo]: docs/images/nzbget.png
[deluge-link]: https://hub.docker.com/r/linuxserver/deluge
[deluge-logo]: docs/images/deluge.png
[jackett-link]: https://hub.docker.com/r/linuxserver/jackett
[jackett-logo]: docs/images/jackett.png
[portainer-link]: https://hub.docker.com/r/portainer/portainer
[portainer-logo]: docs/images/portainer.png
[pia-link]: https://hub.docker.com/r/qmcgaw/private-internet-access
[pia-logo]: docs/images/private-internet-access.png
[tiny-proxy-link]: https://hub.docker.com/r/dannydirect/tinyproxy
[tiny-proxy-logo]: docs/images/tiny-proxy.png


### Requirements
- [docker-compose](https://docs.docker.com/compose/install/#install-using-pip) †
- [Private Internet Access](https://www.privateinternetaccess.com/) account (non-free) *

\* required for secure torrent support

### Windows Requirements ††
- [docker-machine](https://docs.docker.com/machine/install-machine/)
- [VirtualBox 6](https://www.virtualbox.org/wiki/Downloads)
- [Git for Windows](https://gitforwindows.org/) - _WSL bash is not supported_

Project path must be shared as `\\?\dokarr` to env.CIFS_USERNAME with write access

**TODO**: document creating a CIFS share and adding firewall rules. PRs welcome.<br>

_Windows users can add `machine/share/DockerMachineStartupTask.cmd` to Task Scheduler
to start docker-machine on system boot._

† `docker-compose` is provided in the VM but it's recommended to use a native install<br>

†† Will also work for Mac OS and Linux users but there's no reason to use a CIFS mount
   unless using VirtualBox.

### Windows & Linux Interoperability

Dokarr is designed to work across operating systems if using a disk formatted as NTFS.
Due to differences in symlink handling between CIFS [mfsymlinks](https://wiki.samba.org/index.php/UNIX_Extensions#Minshall.2BFrench_symlinks) 
and POSIX symlinks a conversion process must be run to recreate symlinks once booted
to the new OS. The `convert-symlinks` script is provided to handle this process. Note
that this is a **very slow** operation depending on the size of your media library.


```
./machine/share/convert-symlinks.sh -r "config/nginx/certs"
./machine/share/convert-symlinks.sh -r "config/plex/Library/Application Support/Plex Media Server/Metadata"
```

### Reverse Proxy
The compose file is configured to make all services available via [*.xip.io](http://xip.io/),
e.g. `plex.192.168.100.99.xip.io`, the default port for the reverse proxy is `8080`,
configurable in `.env`. An additional domain may be added by setting `HTTP_HOST` in `.env`.

SSL is also supported with certificates issued by [Let's Encrypt](https://letsencrypt.org/), see the section below.

### SSL
SSL support can be added by setting three environment variables. However, it is
**highly recommended** that you run the project once and secure the login pages
to each service by accessing them locally via the `*.xip.io` magic domain by
setting up authentication.

Additionally, Let's Encrypt must be able to access each domain,
e.g. `sonarr.${env.HTTP_HOST}`, make sure port forwarding is correctly configured
on your router, `env.HTTP_PORT` is allowed through your firewall and your domain
is correctly configured to point to your WAN address. This should be tested before
proceeding.

Note: HSTS is enabled, once SSL support is enabled `${env.HTTP_HOST)` is only
accessible via SSL.

Once the above is done modify these `.env` variables:
- LE_HOST_KEY=LETSENCRYPT_HOST
- HTTP_HOST=yourdomain.com
- LETSENCRYPT_EMAIL=you@yourdomain.com

Finally it's recommended to bring up the `nginx` and `letsencrypt` containers
before any others if certificates have not previously been generated. This will
minimize any validation errors due to the way [letsencrypt-nginx-proxy-companion](https://github.com/JrCs/docker-letsencrypt-nginx-proxy-companion)
interacts with [nginx-proxy](https://github.com/jwilder/nginx-proxy).

```bash
docker-compose up -d nginx letsencrypt
sleep 10
docker-compose up -d
```

### Quickstart
```bash
# add bin to PATH to make the dokarr cli available
PATH=$PATH/bin:$PATH

# copy .env-dist to .env
cp .env-dist .env

# set PIA_USERNAME and PIA_PASSWORD and additionally CIFS_USERNAME, CIFS_PASSWORD
# if using a CIFS mount, e.g. Windows users. additional settings are in the .env
# file, tweak them to your liking
vi .env

# create dokarr docker-machine - VirtualBox users only
dokarr create:vm

# source docker-machine environment - VirtualBox users only
eval $(dokarr env)

# start docker containers
dokarr -D

# stop docker containers
dokarr stop
```
