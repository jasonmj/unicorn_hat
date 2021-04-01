FROM elixir:1.11.3

RUN apt-get update && \
    apt-get install -y avahi-daemon avahi-discover avahi-utils libnss-mdns iputils-ping dnsutils build-essential automake autoconf bc cpio git squashfs-tools ssh-askpass pkg-config curl wget rsync
RUN wget https://github.com/fhunleth/fwup/releases/download/v1.8.4/fwup_1.8.4_amd64.deb && \
    dpkg -i ./fwup_1.8.4_amd64.deb
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix archive.install --force hex nerves_bootstrap
COPY ./avahi-daemon.conf /etc/avahi/avahi-daemon.conf
WORKDIR /app
RUN useradd -ms /bin/bash nerves
RUN chown -R nerves /app
# USER nerves
