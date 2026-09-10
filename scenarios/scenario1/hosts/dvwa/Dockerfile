FROM ghcr.io/digininja/dvwa:latest

ARG WAZUH_VERSION=4.14.7
ARG WAZUH_REVISION=1

ENV DEBIAN_FRONTEND=noninteractive \
    WAZUH_VERSION=${WAZUH_VERSION} \
    WAZUH_REVISION=${WAZUH_REVISION} \
    WAZUH_MANAGER=172.30.30.10 \
    WAZUH_AGENT_NAME=dvwa-host

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends iproute2 \
    && rm -rf /var/lib/apt/lists/*

COPY baseline/hosts/agent/ /cyaichi/agent/
COPY scenario1/hosts/dvwa/route-via-fw.sh /cyaichi/route-via-fw.sh
COPY scenario1/hosts/dvwa/entrypoint.sh /cyaichi/entrypoint.sh
RUN chmod 755 /cyaichi/agent/policy-rc.d \
      /cyaichi/agent/install-wazuh-agent.sh \
      /cyaichi/agent/start-wazuh-agent.sh \
      /cyaichi/route-via-fw.sh \
      /cyaichi/entrypoint.sh \
    && /cyaichi/agent/install-wazuh-agent.sh

ENTRYPOINT ["/cyaichi/entrypoint.sh"]
CMD ["apache2-foreground"]
