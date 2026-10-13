FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG USER_UID=1000
ARG USER_GID=1000
# 0 = use Ubuntu's own Mesa (noble-updates); 1 = add the kisak-mesa PPA for a newer Mesa.
ARG KISAK_PPA=0
# npm dist-tag or exact version of Claude Code to install (e.g. 2.1.287).
ARG CLAUDE_CODE_VERSION=latest

# Don't let package post-install scripts try to start services during the build.
RUN printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d && chmod +x /usr/sbin/policy-rc.d

# --- Base tools ---
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg jq \
    && rm -rf /var/lib/apt/lists/*

# --- Optional: kisak-mesa PPA added by hand (build with KISAK_PPA=1) ---
RUN install -m 0755 -d /etc/apt/keyrings \
    && if [ "$KISAK_PPA" = "1" ]; then \
         FP="$(curl -fsSL --retry 5 --connect-timeout 15 https://api.launchpad.net/devel/~kisak/+archive/ubuntu/kisak-mesa | jq -r .signing_key_fingerprint)" \
         && test -n "$FP" && test "$FP" != "null" \
         && curl -fsSL --retry 5 --connect-timeout 15 "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${FP}" \
            | gpg --dearmor -o /etc/apt/keyrings/kisak-mesa.gpg \
         && echo "deb [signed-by=/etc/apt/keyrings/kisak-mesa.gpg] https://ppa.launchpadcontent.net/kisak/kisak-mesa/ubuntu noble main" \
            > /etc/apt/sources.list.d/kisak-mesa.list; \
       fi

# --- Dev tools + Mesa ---
RUN apt-get update && apt-get install -y --no-install-recommends \
      git openssh-client build-essential python3 ripgrep tmux procps unzip \
      iptables util-linux inotify-tools tini \
      mesa-vulkan-drivers libgl1-mesa-dri libegl1 libgbm1 libvulkan1 vulkan-tools \
    && dpkg -s mesa-vulkan-drivers | grep '^Version' \
    && rm -rf /var/lib/apt/lists/*

# --- Docker engine (runs INSIDE this container; needs the Sysbox runtime) ---
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y --no-install-recommends \
      docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# --- GitHub CLI (credential helper + gh pr/gh repo) ---
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# --- Node.js + Claude Code ---
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}"

# --- Chromium system libraries (browser binary comes from your project's
#     `npx playwright install chromium`, stored in the home volume) ---
RUN npx -y playwright@latest install-deps chromium \
    && rm -rf /var/lib/apt/lists/*

# --- Non-root user (replaces default 'ubuntu'), allowed to use inner Docker ---
RUN (userdel -r ubuntu || true) && (groupdel ubuntu || true) \
    && groupadd -g ${USER_GID} dev \
    && useradd -m -u ${USER_UID} -g ${USER_GID} -s /bin/bash dev \
    && usermod -aG docker dev \
    && mkdir -p /work /sessions /shared && chown dev:dev /work /sessions /shared

ENV PLAYWRIGHT_BROWSERS_PATH=/home/dev/.cache/ms-playwright

COPY session.sh /usr/local/bin/session
COPY workspace-CLAUDE.md /etc/claude-workspace/CLAUDE.md
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/session

WORKDIR /sessions
# tini is PID 1 so orphaned processes (headless Chrome, npm, ...) get reaped instead of
# piling up as zombies. entrypoint.sh starts as root, then re-executes itself as dev.
ENTRYPOINT ["tini", "--", "/usr/local/bin/entrypoint.sh"]

