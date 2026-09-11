# Official Kali last-release snapshot (not kali-rolling). Keep this pin in
# baseline/versions.yaml. kali-linux-everything is the full tools metapackage.
FROM kalilinux/kali-last-release

COPY attacker/policy-rc.d /cyaichi/policy-rc.d
RUN install -m 0755 /cyaichi/policy-rc.d /usr/sbin/policy-rc.d \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        -o Dpkg::Options::=--force-confdef \
        -o Dpkg::Options::=--force-confold \
        kali-linux-everything \
        openssh-server \
        sudo \
    && useradd --create-home --shell /bin/bash --user-group kali \
    && echo 'kali ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/kali \
    && chmod 440 /etc/sudoers.d/kali \
    && rm -rf /var/lib/apt/lists/*

COPY route-via-fw.sh /cyaichi/route-via-fw.sh
COPY attacker/entrypoint.sh /cyaichi/entrypoint.sh
COPY attacker/campaign.sh /cyaichi/campaign.sh
COPY attacker/sshd_config /etc/ssh/sshd_config.d/cyaichi.conf
RUN chmod +x /cyaichi/route-via-fw.sh /cyaichi/entrypoint.sh /cyaichi/campaign.sh \
      /cyaichi/policy-rc.d

WORKDIR /opt/cyaichi
ENTRYPOINT ["/cyaichi/entrypoint.sh"]
