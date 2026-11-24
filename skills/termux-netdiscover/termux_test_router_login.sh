#!/data/data/com.termux/files/usr/bin/bash
# termux_test_router_login - Test default credentials on router
# Usage: termux_test_router_login.sh <router_ip>
# Output: JSON with results (only verified successes)

set -euo pipefail

ROUTER_IP="${1:-}"
if [ -z "$ROUTER_IP" ]; then
    echo '{"error":"router_ip required"}'
    exit 1
fi

output_json() {
    local success="$1"
    local creds="$2"
    local method="$3"
    local details="${4:-}"
    printf '{"success":%s,"credentials":"%s","method":"%s","details":"%s"}\n' "$success" "$creds" "$method" "$details"
}

# Common default credentials
CREDENTIALS=(
    "admin:admin"
    "admin:password"
    "admin:1234"
    "admin:12345"
    "admin:"
    "admin:admin123"
    "root:admin"
    "root:root"
    "root:password"
    "root:1234"
    "user:user"
    "user:password"
    "cisco:cisco"
    "ubnt:ubnt"
)

# Common login paths to test
LOGIN_PATHS=(
    "/"
    "/login"
    "/login.html"
    "/index.html"
    "/cgi-bin/login"
    "/cgi-bin/luci"
    "/api/login"
    "/goform/login"
    "/boaform/login"
    "/user/login"
    "/web/login"
    "/admin/login"
    "/management/login"
)

test_http_basic_verified() {
    local ip="$1"
    local user="$2"
    local pass="$3"
    local scheme="$4"

    local url="${scheme}://${ip}"
    local auth="${user}:${pass}"

    # Test: Try to access a protected page (dashboard, status, admin)
    local protected_paths=("/status" "/dashboard" "/admin" "/system_status" "/info" "/status.html" "/admin.html")
    for path in "${protected_paths[@]}"; do
        local protected_response
        protected_response=$(timeout 3 curl -s --max-time 3 -u "$auth" "${url}${path}" 2>/dev/null || echo "")
        if [ -n "$protected_response" ] && ! echo "$protected_response" | grep -qiE "(login|password|sign.in|401|403|unauthorized)"; then
            # Check for router-like content
            if echo "$protected_response" | grep -qiE "(router|gateway|wan|lan|dhcp|wifi|wireless|firmware|uptime|status|connected|devices|clients|bandwidth|traffic)"; then
                output_json "true" "${user}:${pass}" "${scheme}-basic-auth-verified" "Accessed protected page ${path} with router content"
                return 0
            fi
        fi
    done

    return 1
}

test_form_login_verified() {
    local ip="$1"
    local user="$2"
    local pass="$3"
    local scheme="$4"

    local url="${scheme}://${ip}"
    local cookie_file="/tmp/cookies_${ip}_${user}.txt"

    local form_paths=("/login.cgi" "/cgi-bin/login" "/goform/login" "/boaform/login" "/api/login" "/user/login.cgi" "/login" "/login.html")
    for path in "${form_paths[@]}"; do
        # GET login page first
        local login_page
        login_page=$(timeout 5 curl -s --max-time 5 -c "$cookie_file" -b "$cookie_file" "${url}${path}" 2>/dev/null || echo "")

        if [ -z "$login_page" ]; then
            continue
        fi

        # Extract form action if present
        local form_action
        form_action=$(echo "$login_page" | grep -oE 'form[^>]*action=["\x27][^"\x27]*["\x27]' | head -1 | sed -E 's/.*action=["\x27]([^"\x27]*)["\x27].*/\1/')
        local post_url="${url}${path}"
        if [ -n "$form_action" ]; then
            if [[ "$form_action" =~ ^http ]]; then
                post_url="$form_action"
            elif [[ "$form_action" =~ ^/ ]]; then
                post_url="${url}${form_action}"
            else
                post_url="${url}/${form_action}"
            fi
        fi

        # Try common field names
        local field_combinations=(
            "username=${user}&password=${pass}"
            "user=${user}&pass=${pass}"
            "login=${user}&password=${pass}"
            "admin_name=${user}&admin_password=${pass}"
            "http_username=${user}&http_password=${pass}"
        )

        for post_data in "${field_combinations[@]}"; do
            local response
            response=$(timeout 5 curl -s --max-time 5 -X POST -d "$post_data" -H "Content-Type: application/x-www-form-urlencoded" -c "$cookie_file" -b "$cookie_file" -L "$post_url" 2>/dev/null || echo "")

            # Check for success indicators
            local success_pattern="logout|dashboard|status|wan|lan|dhcp|wireless|wifi|firmware|uptime|connected|devices|clients|bandwidth|traffic|system.*status|router"
            local login_pattern="login|password|sign.in|autentica|iniciar.sesion"
            if echo "$response" | grep -qiE "$success_pattern"; then
                # Verify it's not a login page
                if ! echo "$response" | grep -qiE "$login_pattern"; then
                    output_json "true" "${user}:${pass}" "${scheme}-form-${path}" "Form login succeeded, accessed dashboard"
                    rm -f "$cookie_file"
                    return 0
                fi
            fi
        done
    done

    rm -f "$cookie_file"
    return 1
}

main() {
    echo "["
    local first=true

    for cred in "${CREDENTIALS[@]}"; do
        IFS=':' read -r user pass <<< "$cred"

        # Test HTTP Basic Auth (verified) - fast
        if test_http_basic_verified "$ROUTER_IP" "$user" "$pass" "http"; then
            [ "$first" = true ] && first=false || echo ","
            continue
        fi

        # Quick check: try HTTPS if HTTP worked (rarely needed)
        # if test_http_basic_verified "$ROUTER_IP" "$user" "$pass" "https"; then
        #     [ "$first" = true ] && first=false || echo ","
        #     continue
        # fi
    done

    echo "]"
}

main