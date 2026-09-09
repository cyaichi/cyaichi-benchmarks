FROM alpine:3.20
RUN apk add --no-cache chrony \
    && mkdir -p /var/lib/chrony /var/run/chrony
COPY chrony.conf /etc/chrony/chrony.conf
# -x: serve time, do not step the container clock (Docker uses the host).
CMD ["chronyd", "-d", "-x"]
