# dockarr

Docker media server with letsencrypt support. Stability on Windows is the focus but Mac OS and Linux support should work too. A major motivation for this project is to have my media server available when switching between Windows and Ubuntu.

**Included Servers**
- [plex](https://hub.docker.com/r/linuxserver/plex)
- [sonarr](https://hub.docker.com/r/linuxserver/sonarr)
- [radarr](https://hub.docker.com/r/linuxserver/radarr)
- [lidarr](https://hub.docker.com/r/linuxserver/lidarr)
- [jackett](https://hub.docker.com/r/linuxserver/jackett)
- [pia vpn](https://hub.docker.com/r/qmcgaw/private-internet-access)
  - [deluge](https://hub.docker.com/r/linuxserver/deluge)
  - [http proxy](https://hub.docker.com/r/dannydirect/tinyproxy)
- [nzbget](https://hub.docker.com/r/linuxserver/nzbget)
- [portainer](https://hub.docker.com/r/portainer/portainer)

**Requirements**
- [Private Internet Access](https://www.privateinternetaccess.com/) - non-free
- [docker-compose](https://docs.docker.com/compose/install/#install-using-pip) †

**Windows Requirements** ††
- [VirtualBox 6.x](https://www.virtualbox.org/wiki/Downloads)
- [docker-machine](https://docs.docker.com/machine/install-machine/)
- [Git for Windows](https://gitforwindows.org/) - _WSL bash is not supported_
- Project path shared as `\\?\dokarr` to env.CIFS_USERNAME with full access

TODO: document creating a CIFS share and adding firewall rules. PRs welcome.

_Windows users can add `machine/share/DockerMachineStartupTask.cmd` to Task Scheduler to start docker-machine on system boot._

† `docker-compose` is provided in the VM but it's recommended to use a native install<br>
†† Will also work for Mac OS and Linux users but there's no reason to use a CIFS mount unless using VirtualBox.

**Reverse Proxy**<br>
The compose file is configured to make all services available via [*.xip.io](http://xip.io/), e.g. `plex.192.168.100.99.xip.io`, the default port for the reverse proxy is 8080, configurable in `.env`. An additional domain may be added by setting `HTTP_HOST` in `.env`.

SSL is also supported with certificates issued by [Let's Encrypt](https://letsencrypt.org/), see the section below.

**SSL**<br>
SSL support can be added by setting three environment variables. However, it is **highly recommended** that you run the project once and secure the login pages to each service by accessing them locally via the `*.xip.io` magic domain by setting up authentication.

Additionally, Let's Encrypt must be able to access each domain, e.g. `sonarr.${env.HTTP_HOST}`, make sure port forwarding is correctly configured on your router, `env.HTTP_PORT` is allowed through your firewall and your domain is correctly configured to point to your WAN address. This should be tested before proceeding.

Note: HSTS is enabled, once SSL support is enabled `${env.HTTP_HOST)` is only accessible via SSL.

Once the above is done modify these `.env` variables:
- LE_HOST_KEY=LETSENCRYPT_HOST
- HTTP_HOST=yourdomain.com
- LETSENCRYPT_EMAIL=you@yourdomain.com

Finally it's recommended to bring up the `nginx` and `letsencrypt` containers before any others if certificates have not previously been generated. This will minimize any validation errors due to the way [letsencrypt-nginx-proxy-companion](https://github.com/JrCs/docker-letsencrypt-nginx-proxy-companion) interacts with [nginx-proxy](https://github.com/jwilder/nginx-proxy).

```bash
docker-compose up -d nginx letsencrypt
sleep 10
docker-compose up -d
```

**Quickstart**
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
