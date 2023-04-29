# dokarr

Docker Compose Media Server stack containing the popular \*arr applications with
optional support for Let's Encrypt.

**Includes:**

 - <img alt="deluge" src="docs/images/deluge.png" width="12px"></img> **[Deluge][deluge]** a lightweight BitTorrent client with web based management interface
 - <img alt="gluetun" src="docs/images/gluetun.png" width="12px"></img> **[Gluetun][gluetun]** VPN client to anonymize IP
 - <img alt="kavita" src="docs/images/kavita.png" width="12px"></img> **[Kavita][kavita]** free and open source web based ebook, manga and comic reader
 - <img alt="lidarr" src="docs/images/lidarr.png" width="12px"></img> **[Lidarr][lidarr]** looks and smells like Sonarr but made for music
 - <img alt="nzbget" src="docs/images/nzbget.png" width="12px"></img> **[NZBGet][nzbget]** an efficient Usenet Downloader
 - <img alt="overseerr" src="docs/images/overseerr.png" width="12px"></img> **[Overseerr][overseerr]** request management and media discovery tool
 - <img alt="plex" src="docs/images/plex.png" width="12px"></img> **[Plex][plex]** organize all of your personal media so you can enjoy it no matter where you are
 - <img alt="portainer" src="docs/images/portainer.png" width="12px"></img> **[Portainer][portainer]** simple management UI for Docker
 - <img alt="prowlarr" src="docs/images/prowlarr.png" width="12px"></img> **[Prowlarr][prowlarr]** indexer manager/proxy for nzb and torrent
 - <img alt="radarr" src="docs/images/radarr.png" width="12px"></img> **[Radarr][radarr]** a fork of Sonarr to work with movies à la Couchpotato
 - <img alt="readarr" src="docs/images/readarr.png" width="12px"></img> **[Readarr][readarr]** ebook and audiobook collection manager for Usenet and BitTorrent users
 - <img alt="sonarr" src="docs/images/sonarr.png" width="12px"></img> **[Sonarr][sonarr]** smart PVR for newsgroup and bittorrent users
 - <img alt="tautulli" src="docs/images/tautulli.png" width="12px"></img> **[Tautulli][tautulli]** monitoring and tracking tool for Plex Media Server

[plex]: https://hub.docker.com/r/linuxserver/plex
[tautulli]: https://hub.docker.com/r/linuxserver/tautulli
[sonarr]: https://hub.docker.com/r/linuxserver/sonarr
[radarr]: https://hub.docker.com/r/linuxserver/radarr
[lidarr]: https://hub.docker.com/r/linuxserver/lidarr
[readarr]: https://hub.docker.com/r/linuxserver/readarr
[overseerr]: https://hub.docker.com/r/linuxserver/overseerr
[kavita]: https://hub.docker.com/r/kizaing/kavita
[nzbget]: https://hub.docker.com/r/linuxserver/nzbget
[deluge]: https://hub.docker.com/r/linuxserver/deluge
[prowlarr]: https://hub.docker.com/r/linuxserver/prowlarr
[gluetun]: https://hub.docker.com/r/qmcgaw/gluetun
[portainer]: https://hub.docker.com/r/portainer/portainer

## Requirements

- 🐧 Linux distribution capable of running Docker
- 🐳 [Docker](https://docs.docker.com/engine/install/) and [Docker Compose](https://docs.docker.com/compose/install/other/#on-linux)
- 🕵🏼 [Mullvad VPN](https://mullvad.net/) (required for secure torrent support)

## Configuration

### Reverse Proxy

The compose file is configured to make all services available via [*.sslip.io](http://sslip.io/),
e.g. `portainer.192-168-100-99.sslip.io`. The default port for the reverse proxy
is `8080` and can be configured by editing `.env`. An additional domain may be
specified by setting `HTTP_HOST` in `.env`.

SSL is also supported with certificates issued by [Let's Encrypt](https://letsencrypt.org/),
see the section below.

### SSL

SSL support can be added by setting three environment variables. However, it is
**highly recommended** that you run the project once and secure the login pages
to each service by accessing them locally via the `*.sslip.io` magic domain by
setting up authentication.

Additionally, Let's Encrypt must be able to access each domain, e.g.
`portainer.${env.HTTP_HOST}`, make sure port forwarding is correctly configured
on your router, `env.HTTP_PORT` is allowed through your firewall and your domain
is correctly configured to point to your WAN address. This should be tested
before proceeding.

> ⚠️ HSTS will force SSL to be required when accessing `${env.HTTP_HOST)`.

To enable SSL, set the below `.env` variables:

```dotenv
# the top-level domain for the media server
HTTP_HOST=yourdomain.com

# value must be exactly LETSENCRYPT_HOST
LE_HOST_KEY=LETSENCRYPT_HOST

# e-mail address to receive certificate expiry notifications to
LETSENCRYPT_EMAIL=you@yourdomain.com
```

Finally, it's recommended to bring up the `nginx` and `letsencrypt` containers
before any others if certificates have not previously been generated. This will
minimize any validation errors when starting other services.

```sh
docker-compose up nginx letsencrypt
```

### Plex NVIDIA hardware transcoding

Ensure the [NVIDIA Container Runtime](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html#docker)
is installed and functioning correctly and set `PLEX_RUNTIME` in `.env`:

```dotenv
PLEX_RUNTIME=nvidia
```
