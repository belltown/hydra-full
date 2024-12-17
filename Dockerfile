#
# Dockerfile for hydra-full
#

FROM debian:bookworm-slim

ARG HYDRA_VERSION="9.5"
ARG INCLUDE_SECLISTS="false"

LABEL \
    org.opencontainers.image.url="https://github.com/belltown/hydra-full" \
    org.opencontainers.image.source="https://github.com/belltown/hydra-full" \
    org.opencontainers.image.version="${HYDRA_VERSION}" \
    org.opencontainers.image.vendor="belltown" \
    org.opencontainers.image.title="hydra-full" \
    org.opencontainers.image.description="hydra built with SMB2 support" \
    org.opencontainers.image.authors="belltown"

RUN DEBIAN_FRONTEND=noninteractive set -x && apt-get update && apt-get install -y \
    curl \
    default-libmysqlclient-dev \
    desktop-file-utils \
    firebird-dev \
    freerdp2-dev \
    libgcrypt20-dev \
    libgpg-error-dev \
    libgtk2.0-dev \
    libidn11-dev \
    libmemcached-dev \
    libmongoc-1.0-0 \
    libncurses5-dev \
    libpcre3-dev \
    libpq-dev \
    libsmbclient-dev \
    libssh-dev \
    libssl-dev \
    libsvn-dev \
    make \
    tar \
    && c_rehash

WORKDIR /src

ADD https://github.com/vanhauser-thc/thc-hydra/archive/refs/tags/v${HYDRA_VERSION}.tar.gz .
RUN tar -xzf v${HYDRA_VERSION}.tar.gz

WORKDIR /src/thc-hydra-${HYDRA_VERSION}

# Build
RUN make clean && ./configure && make && make install

# Clean-up
RUN apt-get purge -y make \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /src

# User a non-privileged user
RUN useradd -ms /bin/bash myuser

# Verify hydra installation
RUN hydra -h || error_code=$? \
    && if [ ! "${error_code}" -eq 255 ]; then echo "Wrong exit code for 'hydra help' command"; exit 1; fi

# Optionally include usernames and passwords from seclists
RUN \
    if [ "${INCLUDE_SECLISTS}" = "true" ]; \
    then \
        mkdir /tmp/seclists \
        && curl -SL "https://api.github.com/repos/danielmiessler/SecLists/tarball" -o /tmp/seclists/src.tar.gz \
        && tar -xzf /tmp/seclists/src.tar.gz -C /tmp/seclists \
        && mv /tmp/seclists/*SecLists*/Passwords /opt/passwords \
        && mv /tmp/seclists/*SecLists*/Usernames /opt/usernames \
        && chmod -R u+r /opt/passwords /opt/usernames \
        && rm -Rf /tmp/seclists \
        && ls -la /opt/passwords /opt/usernames ; \
    fi

USER myuser

# User should map using bind mount to this directory
WORKDIR /app
