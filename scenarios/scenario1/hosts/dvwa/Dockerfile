FROM ghcr.io/digininja/dvwa:latest

USER root
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends iproute2 \
    && rm -rf /var/lib/apt/lists/*

COPY route-via-fw.sh /cyaichi/route-via-fw.sh
COPY entrypoint.sh /cyaichi/entrypoint.sh
RUN chmod +x /cyaichi/route-via-fw.sh /cyaichi/entrypoint.sh

ENTRYPOINT ["/cyaichi/entrypoint.sh"]
CMD ["apache2-foreground"]
