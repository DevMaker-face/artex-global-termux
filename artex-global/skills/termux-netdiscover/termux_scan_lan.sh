#!/data/data/com.termux/files/usr/bin/bash
# termux_scan_lan - Scan local network for active hosts in Termux
# Usage: termux_scan_lan.sh [network_cidr]
# Output: JSON array of discovered hosts

set -euo pipefail

NETWORK="${1:-}"
if [ -z "$NETWORK" ]; then
    # Try to discover gateway first
    GATEWAY_JSON=$(/data/data/com.termux/files/home/artex-data/skills/termux-netdiscover/termux_discover_gateway.sh)
    GATEWAY=$(echo "$GATEWAY_JSON" | grep -oE '"gateway":"([^"]+)"' | sed 's/.*"gateway":"\([^"]*\)".*/\1/')
    if [ -n "$GATEWAY" ]; then
        # Derive /24 network
        NETWORK=$(echo "$GATEWAY" | sed 's/\.[0-9]*$/.0\/24/')
    else
        NETWORK="192.168.1.0/24"
    fi
fi

output_json() {
    local ip="$1"
    local hostname="${2:-}"
    local method="$3"
    local ports="${4:-}"
    printf '{"ip":"%s","hostname":"%s","method":"%s","open_ports":%s}\n' "$ip" "$hostname" "$method" "$ports"
}

# Parse CIDR
parse_cidr() {
    local cidr="$1"
    local ip="${cidr%/*}"
    local prefix="${cidr#*/}"
    echo "$ip $prefix"
}

# Method 1: nmap ping scan (if available)
scan_nmap() {
    local network="$1"
    if command -v nmap >/dev/null 2>&1; then
        nmap -sn "$network" -oG - 2>/dev/null | grep "Up$" | while read -r line; do
            local ip
            ip=$(echo "$line" | awk '{print $2}')
            local hostname
            hostname=$(echo "$line" | awk '{print $3}' | tr -d '()')
            output_json "$ip" "$hostname" "nmap-ping" "[]"
        done
        return 0
    fi
    return 1
}

# Method 2: Parallel TCP connect scan (port 80, 443, 22, 23, 53)
scan_tcp_parallel() {
    local network="$1"
    local ip prefix
    read -r ip prefix <<< "$(parse_cidr "$network")"
    local base_ip
    base_ip=$(echo "$ip" | sed 's/\.[0-9]*$//')

    # For /24, scan .1-.254
    local start=1 end=254
    [ "$prefix" = "24" ] || { start=1; end=254; }

    local pids=()
    local results_file
    results_file=$(mktemp)

    for i in $(seq $start $end); do
        (
            target="${base_ip}.${i}"
            # Quick TCP connect to common ports
            for port in 80 443 22 23 53 8080 8443; do
                if timeout 1 bash -c "</dev/tcp/$target/$port" 2>/dev/null; then
                    echo "$target $port" >> "$results_file"
                    break
                fi
            done
        ) &
        pids+=($!)

        # Limit concurrency
        if [ ${#pids[@]} -ge 50 ]; then
            wait "${pids[0]}"
            pids=("${pids[@]:1}")
        fi
    done
    wait "${pids[@]}" 2>/dev/null

    sort -u "$results_file" | while read -r ip port; do
        output_json "$ip" "" "tcp-connect" "[${port}]"
    done
    rm -f "$results_file"
}

# Method 3: ARP scan (if arping available)
scan_arp() {
    local network="$1"
    if command -v arping >/dev/null 2>&1; then
        local ip prefix
        read -r ip prefix <<< "$(parse_cidr "$network")"
        local base_ip
        base_ip=$(echo "$ip" | sed 's/\.[0-9]*$//')

        for i in $(seq 1 254); do
            target="${base_ip}.${i}"
            if timeout 1 arping -c 1 -w 1 "$target" 2>/dev/null | grep -q "reply from"; then
                output_json "$target" "" "arp" "[]"
            fi
        done
        return 0
    fi
    return 1
}

# Method 4: mDNS/Bonjour browse
scan_mdns() {
    if command -v avahi-browse >/dev/null 2>&1; then
        timeout 5 avahi-browse -t -r _services._dns-sd._udp 2>/dev/null | grep -E '^(=|IPv)' | while read -r line; do
            if [[ "$line" =~ IPv4.*\[([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\] ]]; then
                ip="${BASH_REMATCH[1]}"
                output_json "$ip" "" "mdns" "[]"
            fi
        done
        return 0
    fi
    return 1
}

# Main
main() {
    echo "["
    local first=true

    # Try methods in order
    if scan_nmap "$NETWORK"; then
        :
    elif scan_tcp_parallel "$NETWORK"; then
        :
    elif scan_arp "$NETWORK"; then
        :
    elif scan_mdns; then
        :
    fi

    echo "]"
}

main