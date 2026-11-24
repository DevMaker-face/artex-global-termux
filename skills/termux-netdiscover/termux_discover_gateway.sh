#!/data/data/com.termux/files/usr/bin/bash
# termux_discover_gateway - Discover default gateway in Termux without root
# Outputs: JSON with gateway_ip, method, confidence

set -euo pipefail

output_json() {
    local gateway="$1"
    local method="$2"
    local confidence="$3"
    local details="${4:-}"
    printf '{"gateway":"%s","method":"%s","confidence":%s,"details":"%s"}\n' \
        "$gateway" "$method" "$confidence" "$details"
}

# Method 1: Check established connections for LAN gateway pattern
try_established_connections() {
    if command -v ss >/dev/null 2>&1; then
        local gw
        gw=$(timeout 2 ss -tun state established 2>/dev/null | grep -oE '(192\.168\.[0-9]+\.1|10\.[0-9]+\.[0-9]+\.1|172\.(1[6-9]|2[0-9]|3[0-1])\.[0-9]+\.1)' | sort -u | head -1)
        if [ -n "$gw" ]; then
            output_json "$gw" "established-connections" "0.6" "From established TCP connections"
            return 0
        fi
    fi
    return 1
}

# Method 2: Try common gateways with quick TCP connect
try_common_gateways_tcp() {
    local commons=(
        "192.168.1.1"
        "192.168.0.1"
        "192.168.1.254"
        "192.168.100.1"
        "10.0.0.1"
        "10.0.1.1"
        "172.16.0.1"
        "192.168.2.1"
        "192.168.10.1"
        "192.168.50.1"
    )
    for ip in "${commons[@]}"; do
        if timeout 1 bash -c "</dev/tcp/$ip/80" 2>/dev/null || timeout 1 bash -c "</dev/tcp/$ip/443" 2>/dev/null; then
            output_json "$ip" "common-gateway-tcp" "0.5" "TCP port open on common gateway IP"
            return 0
        fi
    done
    return 1
}

# Method 3: Android system properties (non-blocking)
try_android_props() {
    local props=(
        "net.rmnet0.gw"
        "net.rmnet1.gw"
        "net.wlan0.gw"
        "dhcp.wlan0.gateway"
        "dhcp.eth0.gateway"
    )
    for prop in "${props[@]}"; do
        local val
        val=$(timeout 1 getprop "$prop" 2>/dev/null)
        if [ -n "$val" ] && [ "$val" != "0.0.0.0" ] && [[ "$val" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            output_json "$val" "android-property-$prop" "0.85" "Android system property"
            return 0
        fi
    done
    return 1
}

# Method 4: DHCP lease files
try_dhcp_leases() {
    local lease_dirs=(
        "/data/misc/dhcp"
        "/data/vendor/dhcp"
        "/mnt/vendor/dhcp"
    )
    for dir in "${lease_dirs[@]}"; do
        [ -d "$dir" ] || continue
        for lease in "$dir"/*; do
            [ -f "$lease" ] || continue
            local gateway
            gateway=$(timeout 1 grep -iE '(router|gateway|option 3)' "$lease" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
            if [ -n "$gateway" ]; then
                output_json "$gateway" "dhcp-lease" "0.8" "DHCP lease file: $lease"
                return 0
            fi
        done
    done
    return 1
}

# Method 5: termux-wifi-connectioninfo (with timeout)
try_termux_api() {
    if command -v termux-wifi-connectioninfo >/dev/null 2>&1; then
        local info
        info=$(timeout 3 termux-wifi-connectioninfo 2>/dev/null | head -c 2000)
        if [ -n "$info" ]; then
            local gateway
            gateway=$(echo "$info" | grep -oE '"gateway"\s*:\s*"([^"]+)"' | sed 's/.*"gateway"\s*:\s*"\([^"]*\)".*/\1/')
            if [ -n "$gateway" ] && [ "$gateway" != "null" ]; then
                output_json "$gateway" "termux-wifi-connectioninfo" "0.95" "WiFi connection info"
                return 0
            fi
        fi
    fi
    return 1
}

# Method 6: mDNS/Bonjour
try_mdns() {
    if command -v avahi-resolve-host-name >/dev/null 2>&1; then
        local gateway
        gateway=$(timeout 3 avahi-resolve-host-name -4 gateway.local 2>/dev/null | awk '{print $2}')
        if [ -n "$gateway" ]; then
            output_json "$gateway" "mdns-gateway.local" "0.75" "mDNS/Bonjour"
            return 0
        fi
    fi
    return 1
}

# Method 7: UPnP/SSDP discovery
try_upnp() {
    if command -v curl >/dev/null 2>&1; then
        local response
        response=$(timeout 3 curl -s -X M-SEARCH -H 'ST: upnp:rootdevice' -H 'MAN: "ssdp:discover"' -H 'MX: 2' "http://239.255.255.250:1900" 2>/dev/null | head -c 2000)
        if echo "$response" | grep -q "LOCATION:"; then
            local gateway
            gateway=$(echo "$response" | grep -i "location:" | head -1 | grep -oE 'http://([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)' | sed 's|http://||')
            if [ -n "$gateway" ]; then
                output_json "$gateway" "upnp-ssdp" "0.7" "UPnP/SSDP discovery"
                return 0
            fi
        fi
    fi
    return 1
}

# Main: try methods in order of reliability/speed
main() {
    # Fast methods first
    try_established_connections && return 0
    try_android_props && return 0
    try_dhcp_leases && return 0
    try_common_gateways_tcp && return 0
    try_mdns && return 0
    try_upnp && return 0
    try_termux_api && return 0  # Last because it can hang

    # Ultimate fallback
    output_json "192.168.1.1" "fallback-default" "0.1" "No discovery worked, using common default"
}

main