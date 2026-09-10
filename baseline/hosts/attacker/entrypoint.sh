#!/bin/sh
set -e
/cyaichi/route-via-fw.sh 172.30.20.2

mkdir -p /var/lib/cyaichi/ssh /home/kali/.ssh /run/sshd
if [ ! -f /var/lib/cyaichi/ssh/ssh_host_ed25519_key ]; then
  ssh-keygen -q -t ed25519 -f /var/lib/cyaichi/ssh/ssh_host_ed25519_key -N ""
fi
chmod 600 /var/lib/cyaichi/ssh/ssh_host_ed25519_key
chmod 644 /var/lib/cyaichi/ssh/ssh_host_ed25519_key.pub
if [ -f /var/lib/cyaichi/ssh/authorized_keys ]; then
  install -m 0600 -o kali -g kali /var/lib/cyaichi/ssh/authorized_keys /home/kali/.ssh/authorized_keys
fi
chmod 700 /home/kali/.ssh
chown -R kali:kali /home/kali/.ssh
ssh-keygen -A >/dev/null
/usr/sbin/sshd

echo "attacker-host ready; campaign is scenario-provided"
exec sleep infinity
