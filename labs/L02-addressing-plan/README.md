# L2: Enterprise Addressing Plan (IPv4 + IPv6)

## Topology Diagram
```mermaid
graph TD
    A[Meridian Logistics HQ] --> B(Site 1: 10.0.0.0/18)
    A --> C(Site 2: 10.0.64.0/18)
    A --> D(Site 3: 10.0.128.0/18)
    A --> E(Site 4: 10.0.192.0/18)
```

```markdown
## IPv4 Addressing & Summarization Math
*Parent Block chosen: 10.0.0.0/16*

| Site | Summary Block | Subnet Mask | Total IPs |
| :--- | :--- | :--- | :--- |
| Site 1 | 10.0.0.0/18 | 255.255.192.0 | 16,384 |
| Site 2 | 10.0.64.0/18 | 255.255.192.0 | 16,384 |
| Site 3 | 10.0.128.0/18 | 255.255.192.0 | 16,384 |
| Site 4 | 10.0.192.0/18 | 255.255.192.0 | 16,384 |

**Proof of Summarization:**
*All VLANs for Site 1 fall within the bounds of 10.0.0.0/18. For example, our largest VLAN (Data) is 10.0.0.0/22, which ends at 10.0.3.255. The next VLAN (Voice) is 10.0.4.0/23. All of these fit perfectly inside the 10.0.0.0 - 10.0.63.255 range. None of these subnets bleed into the Site 2 block which starts at 10.0.64.0.*

## VLAN Design (Site 1 Example)
*Accounting for 300 users (1,200 / 4) and 2x headroom.*

| VLAN | Purpose | Subnet | Gateway |
| :--- | :--- | :--- | :--- |
| 10 | Data | 10.0.0.0/22 | 10.0.0.1 |
| 20 | Voice | 10.0.4.0/23 | 10.0.4.1 |
| 30 | Server | 10.0.6.0/24 | 10.0.6.1 |
| 40 | Mgmt | 10.0.7.0/24 | 10.0.7.1 |
| 50 | Guest | 10.0.8.0/22 | 10.0.8.1 |
```
```markdown
## IPv6 Addressing
*Parent /48 assigned to each site. /64 assigned per VLAN.*

| Site | Site IPv6 Block | VLAN 10 (Data) | VLAN 20 (Voice) |
| :--- | :--- | :--- | :--- |
| Site 1 | 2001:db8:1::/48 | 2001:db8:1:10::/64 | 2001:db8:1:20::/64 |
| Site 2 | 2001:db8:2::/48 | 2001:db8:2:10::/64 | 2001:db8:2:20::/64 |
| Site 3 | 2001:db8:3::/48 | 2001:db8:3:10::/64 | 2001:db8:3:20::/64 |
| Site 4 | 2001:db8:4::/48 | 2001:db8:4:10::/64 | 2001:db8:4:20::/64 |

## Failure Log (Design Flaws Caught)
**Hypothesis 1:** Allocating a /24 for the Data VLAN.
*Test:* 300 users + 100% growth = 600 IPs. A /24 only provides 254 usable IPs.
*Result:* Exhausted IP pool. 
*Fix:* Re-subnetted to a /22 (1,022 usable IPs) to allow for headroom and future growth.
```

