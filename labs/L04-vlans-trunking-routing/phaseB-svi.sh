#!/usr/bin/env bash
# APEX L4 — Phase B: move inter-VLAN routing from r1 (router-on-a-stick)
# to SVIs on sw1 (layer-3 switch).  Usage: sudo ./phaseB-svi.sh
# Hosts are untouched: the gateway IPs (10.0.X.1) simply move to sw1.
set -euo pipefail
cd "$(dirname "$0")"

LAB=l4
VLANS=(10 20 30 40 50 60)

[[ $EUID -eq 0 ]] || { echo "Run with sudo: sudo ./phaseB-svi.sh"; exit 1; }
pid() { docker inspect -f '{{.State.Pid}}' "clab-$LAB-$1"; }
nx() { local n=$1; shift; nsenter -t "$(pid "$n")" -n "$@"; }

echo "==> Remove router-on-a-stick subinterfaces from r1"
for v in "${VLANS[@]}"; do nx r1 ip link del "r1-sw1.$v" 2>/dev/null || true; done

echo "==> Create SVIs on sw1  (~ Cisco: ip routing / interface vlan X)"
nx sw1 sysctl -qw net.ipv4.ip_forward=1
for v in "${VLANS[@]}"; do
  # Idempotent: skip SVIs that already exist (a second run used to fail with "File exists")
  if nx sw1 ip link show "br0.$v" >/dev/null 2>&1; then echo "   br0.$v already exists - skipping"; continue; fi
  nx sw1 bridge vlan add dev br0 vid "$v" self     # let the switch itself join VLAN X
  nx sw1 ip link add link br0 name "br0.$v" type vlan id "$v"
  nx sw1 ip addr add "10.0.$v.1/24" dev "br0.$v"
  nx sw1 ip link set "br0.$v" up
done

echo "==> Flush host ARP caches (10.0.X.1 now has sw1's MAC, not r1's)"
for v in "${VLANS[@]}"; do nx "pc$v" ip neigh flush all; done

mkdir -p results
{
  echo "### r1 addresses (no VLAN subinterfaces should remain)"
  nx r1 ip -br addr
  echo
  echo "### sw1 SVIs"
  nx sw1 ip -br addr show type vlan
} | tee results/phaseB-state.txt

echo
echo "Done. Next: sudo ./matrix.sh phaseB"
