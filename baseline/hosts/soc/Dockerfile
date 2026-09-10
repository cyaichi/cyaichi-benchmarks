FROM ubuntu:24.04

ARG WAZUH_VERSION=4.14.7
ARG WAZUH_REVISION=1
ARG FILEBEAT_VERSION=7.10.2-2

ENV DEBIAN_FRONTEND=noninteractive \
    WAZUH_VERSION=${WAZUH_VERSION} \
    WAZUH_REVISION=${WAZUH_REVISION} \
    FILEBEAT_VERSION=${FILEBEAT_VERSION}

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        adduser \
        apt-transport-https \
        ca-certificates \
        curl \
        debconf \
        gnupg \
        iproute2 \
        libcap2-bin \
        openssl \
        procps \
        python3 \
        python3-pip \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

COPY soc/policy-rc.d /cyaichi/policy-rc.d
COPY soc/certs.yml /cyaichi/certs.yml
COPY soc/opensearch.yml /cyaichi/opensearch.yml
COPY soc/opensearch_dashboards.yml /cyaichi/opensearch_dashboards.yml
COPY soc/filebeat.yml /cyaichi/filebeat.yml
COPY soc/wazuh.yml /cyaichi/wazuh.yml
COPY soc/heap.options /cyaichi/heap.options
COPY soc/patch-ossec.py /cyaichi/patch-ossec.py
COPY soc/install-wazuh.sh /cyaichi/install-wazuh.sh
RUN chmod 755 /cyaichi/policy-rc.d /cyaichi/install-wazuh.sh \
    && /cyaichi/install-wazuh.sh

COPY soc/lab-credentials.txt /opt/cyaichi/LAB-CREDENTIALS
COPY route-via-fw.sh /cyaichi/route-via-fw.sh
COPY soc/entrypoint.sh /cyaichi/entrypoint.sh
RUN chmod 755 /cyaichi/route-via-fw.sh /cyaichi/entrypoint.sh

WORKDIR /opt/cyaichi
RUN mkdir -p /opt/cyaichi/seed \
    && cp -a /var/lib/wazuh-indexer /opt/cyaichi/seed/indexer \
    && cp -a /var/lib/filebeat /opt/cyaichi/seed/filebeat \
    && cp -a /var/ossec/queue /opt/cyaichi/seed/ossec-queue \
    && cp -a /var/ossec/logs /opt/cyaichi/seed/ossec-logs \
    && cp -a /var/ossec/api/configuration /opt/cyaichi/seed/api-configuration \
    && cp -a /var/ossec/etc/client.keys /opt/cyaichi/seed/client.keys

ENTRYPOINT ["/cyaichi/entrypoint.sh"]
