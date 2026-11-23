# L4 — VLANs, 802.1Q Trunking, Inter-VLAN Routing

**APEX Lab Ladder · Tier 0 · YoungTech** — six VLANs across three switches, 802.1Q trunks with the native VLAN moved off VLAN 1, and inter-VLAN routing done two ways: router-on-a-stick, then SVIs on a layer-3 switch.

## Topology

```mermaid
graph TD
  r1[r1 — router-on-a-stick]
  sw1[sw1 — distribution / L3 switch in Phase B]
  sw2[sw2 — access]
  sw3[sw3 — access]
  r1 ===|trunk 10-60, native 99| sw1
  sw1 ===|trunk| sw2
  sw1 ===|trunk| sw3
  sw1 ---|VLAN 10| pc10
  sw1 ---|VLAN 20| pc20
  sw2 ---|VLAN 30| pc30
  sw2 ---|VLAN 40| pc40
  sw3 ---|VLAN 50| pc50
  sw3 ---|VLAN 60| pc60
```

## VLAN and IP plan

| VLAN | Role | Subnet | Gateway | Host | Switch / port |
|---|---|---|---|---|---|
| 10 | Data | 10.0.10.0/24 | 10.0.10.1 | pc10 — 10.0.10.10 | sw1 / sw1-pc10 |
| 20 | Voice | 10.0.20.0/24 | 10.0.20.1 | pc20 — 10.0.20.10 | sw1 / sw1-pc20 |
| 30 | Servers | 10.0.30.0/24 | 10.0.30.1 | pc30 — 10.0.30.10 | sw2 / sw2-pc30 |
| 40 | Mgmt | 10.0.40.0/24 | 10.0.40.1 | pc40 — 10.0.40.10 | sw2 / sw2-pc40 |
| 50 | Guest | 10.0.50.0/24 | 10.0.50.1 | pc50 — 10.0.50.10 | sw3 / sw3-pc50 |
| 60 | Printers | 10.0.60.0/24 | 10.0.60.1 | pc60 — 10.0.60.10 | sw3 / sw3-pc60 |
| 99 | Native (untagged on trunks) | — | — | none | all trunks |

Gateway lives on **r1** subinterfaces in Phase A and on **sw1** SVIs in Phase B.

## Environment

Windows → WSL2 Ubuntu → Docker + Containerlab v0.83.0 → Alpine Linux nodes. Switches are Linux VLAN-aware bridges (`vlan_filtering 1`). Links are direct veth pairs created by `deploy.sh`.

## Rebuild from zero

```bash
sudo apt install -y tcpdump          # once
sudo ./deploy.sh                     # Phase A: router-on-a-stick
sudo ./matrix.sh phaseA              # 6x6 ping matrix
sudo ./capture.sh                    # tagged vs untagged frames
sudo ./phaseB-svi.sh                 # Phase B: SVIs on sw1
sudo ./matrix.sh phaseB
sudo containerlab destroy -t l4.clab.yml --cleanup
```

## Verification

### Phase A — router-on-a-stick
| src \ dst | pc10 | pc20 | pc30 | pc40 | pc50 | pc60 |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| **pc10** | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| **pc20** | ✅ | — | ✅ | ✅ | ✅ | ✅ |
| **pc30** | ✅ | ✅ | — | ✅ | ✅ | ✅ |
| **pc40** | ✅ | ✅ | ✅ | — | ✅ | ✅ |
| **pc50** | ✅ | ✅ | ✅ | ✅ | — | ✅ |
| **pc60** | ✅ | ✅ | ✅ | ✅ | ✅ | — |

Result (phaseA): 30 passed, 0 failed of 30 inter-host paths
64 bytes from 10.0.60.10: icmp_seq=1 ttl=63 time=0.097 ms

Gateways on r1 subinterfaces `r1-sw1.10`–`.60` (see `results/phaseA-state.txt`). Every trunk carries VLANs 10–60 tagged with VLAN 99 as the untagged PVID; no port is in VLAN 1.

### Phase B — SVIs
| src \ dst | pc10 | pc20 | pc30 | pc40 | pc50 | pc60 |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| **pc10** | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| **pc20** | ✅ | — | ✅ | ✅ | ✅ | ✅ |
| **pc30** | ✅ | ✅ | — | ✅ | ✅ | ✅ |
| **pc40** | ✅ | ✅ | ✅ | — | ✅ | ✅ |
| **pc50** | ✅ | ✅ | ✅ | ✅ | — | ✅ |
| **pc60** | ✅ | ✅ | ✅ | ✅ | ✅ | — |

Result (phaseB): 30 passed, 0 failed of 30 inter-host paths
64 bytes from 10.0.60.10: icmp_seq=1 ttl=63 time=0.115 ms

`results/phaseB-state.txt` shows r1 with **no** VLAN subinterfaces left and the gateways on sw1 SVIs `br0.10`–`br0.60`. The matrix still passes at TTL 63, so sw1 is doing the routing.

### Packet capture
One ping, pc10 (VLAN 10) → pc20 (VLAN 20), captured simultaneously on the trunk and the access port.

**Trunk `sw1-r1`** — `captures/trunk-sw1-r1.pcap`
```
ee:b2:be:5f:4b:19 > 4e:8c:9a:d6:4f:f3, ethertype 802.1Q (0x8100), length 102: vlan 10, p 0, ethertype IPv4, 10.0.10.10 > 10.0.20.10: ICMP echo request
4e:8c:9a:d6:4f:f3 > 3a:cf:7b:6c:ea:b5, ethertype 802.1Q (0x8100), length 102: vlan 20, p 0, ethertype IPv4, 10.0.10.10 > 10.0.20.10: ICMP echo request
```
**Access `sw1-pc10`** — `captures/access-sw1-pc10.pcap`
```
ee:b2:be:5f:4b:19 > 4e:8c:9a:d6:4f:f3, ethertype IPv4 (0x0800), length 98: 10.0.10.10 > 10.0.20.10: ICMP echo request
```

What it shows:
- **102 vs 98 bytes** — the 4-byte difference is the 802.1Q tag (TPID `0x8100` + PCP/DEI/VID).
- **The same packet crosses the trunk twice** — up in VLAN 10, back down in VLAN 20. That is router-on-a-stick on the wire.
- **The MAC addresses are rewritten, the IP addresses are not** — r1 (`4e:8c:…`) replaces the Layer 2 header for the next hop.
- `p 0` is the 802.1p priority field (PCP), unused here.

## Failure log

### Session 1 — 2026-11-22 (original manual build, pc1 / pc2)

**Symptom:** pc1 (10.0.10.10) could ping its gateway 10.0.10.1 but not pc2 (10.0.20.10).

| # | Test | Result | Conclusion |
|---|---|---|---|
| 1 | `ip link show` on sw1 | `eth3` (plain) was in br20, not `eth3.20` | sw1 sent VLAN 20 **untagged** toward sw3 |
| 2 | Rebuilt sw1 uplink as `eth3.20` in br20 | pc1 → pc2 still failed | One fault fixed, another remains |
| 3 | `ping` r1 → pc2 | 3/3 success | VLAN 20 Layer 2 path is good. Fault is Layer 3 |
| 4 | `sysctl net.ipv4.ip_forward` on r1 | `= 1` | Router forwarding OK |
| 5 | `ip route` on pc1 / pc2 | `default via 172.20.20.1 dev eth0` | Hosts send off-subnet traffic to the **mgmt network** |
| 6 | Added `10.0.0.0/16 via` the VLAN gateway, on pc1 only | Still failed | Reply path from pc2 still broken |
| 7 | Same route on pc2 | **4/4, ttl=63** | Inter-VLAN routing working |

**Root cause 1 — trunk mismatch.** sw1 forwarded VLAN 20 untagged out `eth3` while sw3 expected tagged VLAN 20 on `eth1.20`. Cisco equivalent: access port on one end, trunk on the other. The checkpoint notes said `eth3.20` — **documentation drift**. The live config is the truth.

**Root cause 2 — wrong default gateway.** Containerlab installs a default route via its management network (172.20.20.1 on eth0). The intended gateway was never installed ("File exists"). Fixed with a more-specific route — longest prefix match, /16 beats /0 — keeping the out-of-band management path intact.

**Lessons:** troubleshoot bottom-up and divide and conquer. Verify live state, not notes. A ping needs **both** directions. TTL 64 → 63 proves a routed hop.

**Design changes for the rebuild:** one VLAN-aware bridge per switch instead of a bridge per VLAN, so native VLAN 99 is real. Direct veth cables named `A-B`, so no MAC mapping and no stray Docker 172.x addresses. One host per VLAN for a true 6×6 matrix. One-command rebuild.

### Session 2 — 2026-11-22 (clean rebuild with `deploy.sh`)

`deploy.sh`, both matrices and `capture.sh` passed on the first run. Problems found:

| # | Problem | Cause | Fix / lesson |
|---|---|---|---|
| 1 | `bridge: executable file not found` inside Alpine | BusyBox `ip` ships without iproute2's `bridge` | Read `master` from `ip link show`. The rebuild runs host iproute2 inside each node via `nsenter` |
| 2 | Pasted a block of dependent commands, and failures cascaded | `git pull` aborted, then `mv` and `cd` failed and later commands ran in the wrong folder | Run dependent commands one at a time or chain them with `&&` |
| 3 | `git pull` refused: untracked L3 `README.md` would be overwritten | A local copy of a file existed outside git | Moved it aside, pulled, compared with `diff` |
| 4 | Second run of `phaseB-svi.sh`: `RTNETLINK answers: File exists` | Script was not idempotent | Now skips SVIs that already exist |

## Interview summary

_Problem → design → implementation → verification → failure analysis → lessons, in 6 sentences._

**Reading:** Odom, *CCNA 200-301 Official Cert Guide Vol. 1* — VLANs, trunking, inter-VLAN routing chapters.
