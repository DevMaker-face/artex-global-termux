# Termux Network Discovery Skill

Autonomous network discovery for ARTEX running in Termux (Android) without root.

## Purpose

When ARTEX runs in Termux, it cannot access `/proc/net/route`, `ip route`, or ARP tables due to Android sandbox restrictions. This skill provides alternative discovery methods that work within Termux constraints.

## Tools Provided

### `termux_discover_gateway`
Discovers the default gateway/router IP using multiple fallback methods.

**Methods tried (in order):**
1. `termux-wifi-connectioninfo` (via termux-api) - gets gateway from WiFi info
2. `getprop net.*.gw` - Android system properties
3. DHCP lease files in `/data/misc/dhcp/`
4. DNS SRV/PTR queries for `_gateway._tcp.local`
5. mDNS/Bonjour query for `gateway.local`
6. UPnP/SSDP discovery (M-SEARCH)
6. Try common gateway IPs with HTTP HEAD
7. Check established TCP connections for LAN IPs
8. Fallback: return common defaults (192.168.1.1, 192.168.0.1, etc.)

### `termux_scan_lan`
Scans the local network for active hosts using methods available in Termux.

**Methods:**
1. ARP ping sweep (if `arping` available)
2. Parallel HTTP HEAD to common IPs
3. nmap ping scan (if nmap installed)
4. mDNS/Bonjour browse

### `termux_test_router_login`
Tests default credentials against discovered router.

**Tests:**
- HTTP Basic Auth (admin/admin, admin/password, etc.)
- Common router login forms (POST to /login, /cgi-bin/, etc.)
- HTTPS variants

## Usage by ARTEX Agents

The planner/worker can call these tools automatically when network discovery is needed:

```
User: "Check my router credentials"
→ Planner creates intent: "Discover gateway and test admin/admin"
→ Worker calls termux_discover_gateway → gets 192.168.1.1
→ Worker calls termux_test_router_login on 192.168.1.1
→ Reports result
```

## Installation

This skill is auto-loaded from `~/artex-data/skills/termux-netdiscover/`