#!/usr/bin/env bash
# APEX L4 — Phase A: router-on-a-stick
# Builds the whole lab from a blank state in one command:  sudo ./deploy.sh
#
# Design
#   r1 ==trunk== sw1 ==trunk== sw2      (sw2: pc30 VLAN 30, pc40 VLAN 40)
#                 \\===trunk== sw3      (sw3: pc50 VLAN 50, pc60 VLAN 60)
#   sw1 access ports: pc10 VLAN 10, pc20 VLAN 20
#   VLANs 10-60 = 10.0.<vlan>.0/24, gateway .1, host .10
#   Native VLAN 99 (untagged on every trunk, no hosts). VLAN 1 not used anywhere.
#
# Interface naming: the interface on node A facing node B is called "A-B"
# (e.g. sw1-r1 on sw1, r1-sw1 on r1). No MAC-address mapping needed.
set -euo pipefail
cd "$(dirname "$0")"

LAB=l4
VLANS=(10 20 30 40 50 60)
NATIVE=99

[[ $EUID -eq 0 ]] || { echo "Run with sudo: sudo ./deploy.sh"; exit 1; }
for t in containerlab docker nsenter ip bridge; do
  command -v "$t" >/dev/null || { echo "Missing tool: $t"; exit 1; }
done

# PID of a node's container (its network namespace lives at /proc/<pid>/ns/net)
pid() { docker inspect -f '{{.State.Pid}}' "clab-$LAB-$1"; }

# nx NODE CMD...  -> run CMD inside NODE's network namespace using the
# host's full iproute2/tcpdump (Alpine's BusyBox lacks 'bridge').
nx() { local n=$1; shift; nsenter -t "$(pid "$n")" -n "$@"; }

# cable A B  -> one virtual cable: interface "A-B" on A <-> "B-A" on B
cable() {
  local a=$1 b=$2
  ip link add "$a-$b" type veth peer name "$b-$a"
  ip link set "$a-$b" netns "$(pid "$a")"
  ip link set "$b-$a" netns "$(pid "$b")"
  nx "$a" ip link set "$a-$b" up
  nx "$b" ip link set "$b-$a" up
}

# One VLAN-aware bridge per switch = the switch's forwarding fabric.
# vlan_default_pvid 0: ports do NOT silently join VLAN 1.
switch_init() {
  nx "$1" ip link add br0 type bridge vlan_filtering 1 vlan_default_pvid 0
  nx "$1" ip link set br0 up
}

# trunk SW PORT  ~ Cisco: switchport mode trunk
#                         switchport trunk allowed vlan 10,20,30,40,50,60
#                         switchport trunk native vlan 99
trunk() {
  local sw=$1 port=$2
  nx "$sw" ip link set "$port" master br0
  for v in "${VLANS[@]}"; do nx "$sw" bridge vlan add dev "$port" vid "$v"; done
  nx "$sw" bridge vlan add dev "$port" vid "$NATIVE" pvid untagged
}

# access SW PORT VLAN  ~ Cisco: switchport mode access / switchport access vlan X
access() {
  nx "$1" ip link set "$2" master br0
  nx "$1" bridge vlan add dev "$2" vid "$3" pvid untagged
}

# host NAME SWITCH VLAN
host() {
  local h=$1 sw=$2 v=$3
  nx "$h" ip addr add "10.0.$v.10/24" dev "$h-$sw"
  # Lab traffic goes to the VLAN gateway. The containerlab mgmt default route
  # (172.20.20.1 on eth0) stays for out-of-band access - this is ROOT CAUSE 2
  # from session 1: without this more-specific route, off-subnet traffic
  # left via the management network. Longest prefix match: /16 beats /0.
  nx "$h" ip route add 10.0.0.0/16 via "10.0.$v.1"
}

echo "==> [1/6] Blank state: destroy any previous L4 lab"
containerlab destroy -t l4.clab.yml --cleanup >/dev/null 2>&1 || true

echo "==> [2/6] Deploy nodes"
containerlab deploy -t l4.clab.yml

[[ -e /proc/$(pid r1)/ns/net ]] || {
  echo "Can't reach container namespaces. Docker must run inside WSL (docker-ce), not Docker Desktop."
  exit 1
}

echo "==> [3/6] Cabling"
cable r1 sw1
cable sw1 sw2
cable sw1 sw3
cable pc10 sw1; cable pc20 sw1
cable pc30 sw2; cable pc40 sw2
cable pc50 sw3; cable pc60 sw3

echo "==> [4/6] Switches: VLAN-aware bridges, trunks, access ports"
for sw in sw1 sw2 sw3; do switch_init "$sw"; done
trunk sw1 sw1-r1
trunk sw1 sw1-sw2
trunk sw1 sw1-sw3
trunk sw2 sw2-sw1
trunk sw3 sw3-sw1
access sw1 sw1-pc10 10
access sw1 sw1-pc20 20
access sw2 sw2-pc30 30
access sw2 sw2-pc40 40
access sw3 sw3-pc50 50
access sw3 sw3-pc60 60

echo "==> [5/6] Router-on-a-stick on r1 (one subinterface per VLAN)"
nx r1 sysctl -qw net.ipv4.ip_forward=1
for v in "${VLANS[@]}"; do
  nx r1 ip link add link r1-sw1 name "r1-sw1.$v" type vlan id "$v"
  nx r1 ip addr add "10.0.$v.1/24" dev "r1-sw1.$v"
  nx r1 ip link set "r1-sw1.$v" up
done

echo "==> [6/6] Hosts"
for v in "${VLANS[@]}"; do
  case $v in 10|20) sw=sw1;; 30|40) sw=sw2;; *) sw=sw3;; esac
  host "pc$v" "$sw" "$v"
done

mkdir -p results
{
  echo "### sw1 VLAN table (bridge vlan show)"
  nx sw1 bridge vlan show
  echo
  echo "### r1 addresses"
  nx r1 ip -br addr
} | tee results/phaseA-state.txt

echo
echo "Done. Next: sudo ./matrix.sh phaseA"
