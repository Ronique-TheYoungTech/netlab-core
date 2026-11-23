#!/usr/bin/env bash
# Capture a TAGGED trunk frame and an UNTAGGED access frame at the same time.
# Run during Phase A:  sudo ./capture.sh
#   trunk  = sw1-r1   (sw1 <-> r1)   -> frames carry an 802.1Q header
#   access = sw1-pc10 (sw1 <-> pc10) -> same packets, no tag
set -euo pipefail
cd "$(dirname "$0")"

LAB=l4
[[ $EUID -eq 0 ]] || { echo "Run with sudo: sudo ./capture.sh"; exit 1; }
command -v tcpdump >/dev/null || { echo "Install first: sudo apt install -y tcpdump"; exit 1; }
pid() { docker inspect -f '{{.State.Pid}}' "clab-$LAB-$1"; }
nx() { local n=$1; shift; nsenter -t "$(pid "$n")" -n "$@"; }

mkdir -p captures
nx sw1 timeout 6 tcpdump -i sw1-r1   -nn -w captures/trunk-sw1-r1.pcap   2>/dev/null &
nx sw1 timeout 6 tcpdump -i sw1-pc10 -nn -w captures/access-sw1-pc10.pcap 2>/dev/null &
sleep 1

echo "==> pc10 (VLAN 10) pings pc20 (VLAN 20) through the trunk"
nx pc10 ping -c 3 10.0.20.10
wait || true

echo
echo "==> TRUNK (expect 'vlan 10' and 'vlan 20' tags):"
tcpdump -e -nn -r captures/trunk-sw1-r1.pcap 2>/dev/null | grep -i icmp | head -4
echo
echo "==> ACCESS (expect NO vlan tag, ethertype IPv4):"
tcpdump -e -nn -r captures/access-sw1-pc10.pcap 2>/dev/null | grep -i icmp | head -4

echo
echo "Open in Wireshark from Windows:  explorer.exe captures"
echo "Then File > Save As > pcapng for the repo copy."
