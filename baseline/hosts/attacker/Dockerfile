# Official Kali last-release snapshot (not kali-rolling). Keep this pin in
# baseline/versions.yaml. Do not pull kali-linux-* metapackages; campaign
# payloads stay in the scenario pack.
FROM kalilinux/kali-last-release

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        iproute2 \
        openssh-server \
        python3 \
        sudo \
        tzdata \
    && useradd --create-home --shell /bin/bash --user-group kali \
    && echo 'kali ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/kali \
    && chmod 440 /etc/sudoers.d/kali \
    && rm -rf /var/lib/apt/lists/*

COPY route-via-fw.sh /cyaichi/route-via-fw.sh
COPY attacker/entrypoint.sh /cyaichi/entrypoint.sh
COPY attacker/campaign.sh /cyaichi/campaign.sh
COPY attacker/sshd_config /etc/ssh/sshd_config.d/cyaichi.conf
RUN chmod +x /cyaichi/route-via-fw.sh /cyaichi/entrypoint.sh /cyaichi/campaign.sh

WORKDIR /opt/cyaichi
ENTRYPOINT ["/cyaichi/entrypoint.sh"]
