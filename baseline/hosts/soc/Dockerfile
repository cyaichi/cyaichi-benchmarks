FROM ubuntu:24.04

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        iproute2 \
        python3 \
        python3-pip \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

COPY route-via-fw.sh /cyaichi/route-via-fw.sh
COPY soc/entrypoint.sh /cyaichi/entrypoint.sh
RUN chmod +x /cyaichi/route-via-fw.sh /cyaichi/entrypoint.sh

# Wazuh is installed onto this host in a later slice. The machine, networks,
# and data directory are the foundation.
WORKDIR /opt/cyaichi
ENTRYPOINT ["/cyaichi/entrypoint.sh"]
