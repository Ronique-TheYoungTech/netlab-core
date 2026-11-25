#!/usr/bin/env bash
# APEX L5 — builds the topology and starts the legitimate DHCP server.
# Usage: sudo ./deploy.sh
# Defenses are NOT configured here — you add them by hand during the lab.
#
#              gw (10.0.10.1, real DHCP server)
#               |  sw1-gw   <- TRUSTED port
#   pc1 ---- [ sw1 ] ---- pc2
#  .11          |           .12
#               |  sw1-atk  <- attacker's port
#              atk (10.0.10.66)
#
# One VLAN (10.0.10.0/24). Interface "A-B" lives on A and faces B.
set -euo pipefail
cd "$(dirname "$0")"
LAB=l5

[[ $EUID -eq 0 ]] || { echo "Run with sudo: sudo ./deploy.sh"; exit 1; }
for t in containerlab docker nsenter ip bridge tc dnsmasq arpspoof macof tcpdump; do
  command -v "$t" >/dev/null || { echo "Missing tool: $t (see README: Prerequisites)"; exit 1; }
done

pid() { docker inspect -f '{{.State.Pid}}' "clab-$LAB-$1"; }
nx()  { local n=$1; shift; nsenter -t "$(pid "$n")" -n "$@"; }
cable() {
  local a=$1 b=$2
  ip link add "$a-$b" type veth peer name "$b-$a"
  ip link set "$a-$b" netns "$(pid "$a")"
  ip link set "$b-$a" netns "$(pid "$b")"
  nx "$a" ip link set "$a-$b" up
  nx "$b" ip link set "$b-$a" up
}

echo "==> [1/5] Blank state"
pkill -f 'dnsmasq.*l5-' 2>/dev/null || true
containerlab destroy -t l5.clab.yml --cleanup >/dev/null 2>&1 || true
rm -f /tmp/l5-*

echo "==> [2/5] Deploy nodes"
containerlab deploy -t l5.clab.yml

echo "==> [3/5] Cabling"
for n in gw pc1 pc2 atk; do cable "$n" sw1; done

echo "==> [4/5] Switch sw1: one plain bridge, all ports in VLAN 10 (no protections yet)"
nx sw1 ip link add br0 type bridge
nx sw1 ip link set br0 up
for p in sw1-gw sw1-pc1 sw1-pc2 sw1-atk; do nx sw1 ip link set "$p" master br0; done

echo "==> [5/5] Addresses + legitimate DHCP server on gw"
nx gw  ip addr add 10.0.10.1/24  dev gw-sw1
nx pc1 ip addr add 10.0.10.11/24 dev pc1-sw1
nx pc2 ip addr add 10.0.10.12/24 dev pc2-sw1
nx atk ip addr add 10.0.10.66/24 dev atk-sw1
nx gw sysctl -qw net.ipv4.ip_forward=1

# The real DHCP server. dhcp-reply-delay=2 makes it a slow, busy server, so the
# rogue-vs-legit race is repeatable in the lab. (In real networks the rogue often
# wins because it is closer to the victim or less loaded.)
nx gw dnsmasq --conf-file=/dev/null --user=root --port=0 \
  --interface=gw-sw1 --bind-interfaces \
  --dhcp-range=10.0.10.100,10.0.10.150,255.255.255.0,1h \
  --dhcp-option=3,10.0.10.1 \
  --dhcp-reply-delay=2 \
  --dhcp-leasefile=/tmp/l5-gw.leases --pid-file=/tmp/l5-gw.pid \
  --log-dhcp --log-facility=/tmp/l5-gw.log

mkdir -p results captures
{
  echo "### MAC addresses (you'll need these for the defenses)"
  for n in gw pc1 pc2 atk; do
    printf '%-4s %-12s %s\n' "$n" "$n-sw1" "$(nx "$n" cat /sys/class/net/$n-sw1/address)"
  done
} | tee results/macs.txt

echo
echo "Done. Baseline test:  sudo ./nx pc1 ping -c 2 10.0.10.1"
