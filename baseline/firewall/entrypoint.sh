#!/bin/sh
set -e
echo 1 >/proc/sys/net/ipv4/ip_forward

iptables -F
iptables -t nat -F
iptables -P FORWARD DROP
iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT

iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

iptables -P OUTPUT DROP
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -d 172.30.0.0/16 -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

iptables -A FORWARD -s 172.30.20.0/24 -d 172.30.10.0/24 -p tcp -m multiport --dports 80,443 -j ACCEPT

# Asset agents -> SIEM host
iptables -A FORWARD -s 172.30.10.0/24 -d 172.30.30.10 -p tcp -m multiport --dports 1514,1515,55000 -j ACCEPT
iptables -A FORWARD -s 172.30.10.0/24 -d 172.30.30.10 -p udp --dport 1514 -j ACCEPT

# SIEM/SOAR named actions -> asset
iptables -A FORWARD -s 172.30.30.0/24 -d 172.30.10.0/24 -p tcp -m multiport --dports 22,1514,1515 -j ACCEPT

# Test environment -> SIEM API (harness)
iptables -A FORWARD -s 172.30.40.0/24 -d 172.30.30.10 -p tcp -m multiport --dports 443,55000 -j ACCEPT

# Tenants -> DNS / NTP / HTTP proxy on net-egress
for src in 172.30.10.0/24 172.30.20.0/24 172.30.30.0/24; do
  iptables -A FORWARD -s "$src" -d 172.30.50.0/24 -p udp -m multiport --dports 53,123 -j ACCEPT
  iptables -A FORWARD -s "$src" -d 172.30.50.0/24 -p tcp -m multiport --dports 53,3128 -j ACCEPT
done
iptables -A FORWARD -j LOG --log-prefix "cyaichi-fw-drop " --log-level 4
iptables -A FORWARD -j DROP

echo "cyaichi firewall: forwarding on, default deny"
exec sleep infinity
