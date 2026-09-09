FROM alpine:3.20
RUN apk add --no-cache squid \
    && mkdir -p /var/log/squid /var/cache/squid \
    && chown -R squid:squid /var/log/squid /var/cache/squid
CMD ["squid", "-NYCd", "1"]
