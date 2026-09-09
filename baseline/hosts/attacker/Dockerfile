FROM ubuntu:24.04

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        iproute2 \
        python3 \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

COPY route-via-fw.sh /cyaichi/route-via-fw.sh
COPY attacker/entrypoint.sh /cyaichi/entrypoint.sh
COPY attacker/campaign.sh /cyaichi/campaign.sh
RUN chmod +x /cyaichi/route-via-fw.sh /cyaichi/entrypoint.sh /cyaichi/campaign.sh

WORKDIR /opt/cyaichi
ENTRYPOINT ["/cyaichi/entrypoint.sh"]
