#!/bin/bash
# ABOUTME: Initialize iptables-based firewall with allowlist for approved domains
# ABOUTME: Uses pre-aggregated GitHub IP ranges from build time

set -euo pipefail  # Exit on error, undefined vars, and pipeline failures
IFS=$'\n\t'       # Stricter word splitting

# Use full paths for iptables commands (ensures we use our custom legacy symlinks)
IPTABLES="/usr/sbin/iptables-legacy"
IPTABLES_SAVE="/usr/sbin/iptables-legacy-save"
IPSET="/usr/sbin/ipset"

# 1. Extract Docker DNS info BEFORE any flushing
DOCKER_DNS_RULES=$($IPTABLES_SAVE -t nat | grep "127\.0\.0\.11" || true)

# Flush existing rules and delete existing ipsets
$IPTABLES -F
$IPTABLES -X
$IPTABLES -t nat -F
$IPTABLES -t nat -X
$IPTABLES -t mangle -F
$IPTABLES -t mangle -X
$IPSET destroy allowed-domains 2>/dev/null || true

# 2. Selectively restore ONLY internal Docker DNS resolution
if [ -n "$DOCKER_DNS_RULES" ]; then
    echo "Restoring Docker DNS rules..."
    $IPTABLES -t nat -N DOCKER_OUTPUT 2>/dev/null || true
    $IPTABLES -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
    echo "$DOCKER_DNS_RULES" | xargs -L 1 $IPTABLES -t nat
else
    echo "No Docker DNS rules to restore"
fi

# First allow DNS and localhost before any restrictions
# Allow outbound DNS
$IPTABLES -A OUTPUT -p udp --dport 53 -j ACCEPT
# Allow inbound DNS responses
$IPTABLES -A INPUT -p udp --sport 53 -j ACCEPT
# Allow outbound SSH
$IPTABLES -A OUTPUT -p tcp --dport 22 -j ACCEPT
# Allow inbound SSH responses
$IPTABLES -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
# Allow localhost
$IPTABLES -A INPUT -i lo -j ACCEPT
$IPTABLES -A OUTPUT -o lo -j ACCEPT

# Create ipset with CIDR support
$IPSET create allowed-domains hash:net

# Fetch fresh GitHub IP ranges at runtime
echo "Fetching GitHub IP ranges..."
if curl -s --max-time 5 https://api.github.com/meta | \
   jq -r '.web[], .api[], .git[], .packages[]' > /tmp/github-ips.txt 2>/dev/null && \
   [ -s /tmp/github-ips.txt ]; then
    range_count=$(wc -l < /tmp/github-ips.txt)
    echo "✓ Using fresh GitHub ranges ($range_count ranges)"

    while read -r cidr; do
        # Skip IPv6 addresses (contain colons)
        if [[ "$cidr" == *":"* ]]; then
            echo "Skipping IPv6 range: $cidr"
            continue
        fi

        if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
            echo "ERROR: Invalid CIDR range from GitHub API: $cidr"
            exit 1
        fi
        echo "Adding GitHub range $cidr"
        $IPSET add -exist allowed-domains "$cidr"
    done < /tmp/github-ips.txt
else
    echo "⚠ GitHub API unavailable, relying on DNS resolution for GitHub domains"
fi

# Resolve and add other allowed domains
for domain in \
    "registry.npmjs.org" \
    "api.anthropic.com" \
    "claude.ai" \
    "statsig.anthropic.com" \
    "statsig.com" \
    "storage.googleapis.com" \
    "ghcr.io"; do
    echo "Resolving $domain..."
    # Use dig from bind-tools (Alpine package)
    ips=$(dig +noall +answer A "$domain" | awk '$4 == "A" {print $5}')
    if [ -z "$ips" ]; then
        echo "ERROR: Failed to resolve $domain"
        exit 1
    fi

    while read -r ip; do
        if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "ERROR: Invalid IP from DNS for $domain: $ip"
            exit 1
        fi
        echo "Adding $ip for $domain"
        $IPSET add -exist allowed-domains "$ip"
    done < <(echo "$ips")
done

# Get host IP from default route
HOST_IP=$(ip route | grep default | cut -d" " -f3)
if [ -z "$HOST_IP" ]; then
    echo "ERROR: Failed to detect host IP"
    exit 1
fi

HOST_NETWORK=$(echo "$HOST_IP" | sed "s/\.[0-9]*$/.0\/24/")
echo "Host network detected as: $HOST_NETWORK"

# Set up remaining iptables rules
$IPTABLES -A INPUT -s "$HOST_NETWORK" -j ACCEPT
$IPTABLES -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT

# Set default policies to DROP first
$IPTABLES -P INPUT DROP
$IPTABLES -P FORWARD DROP
$IPTABLES -P OUTPUT DROP

# First allow established connections for already approved traffic
$IPTABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Then allow only specific outbound traffic to allowed domains
$IPTABLES -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT

# Explicitly REJECT all other outbound traffic for immediate feedback
$IPTABLES -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

echo "Firewall configuration complete"
echo "Verifying firewall rules..."
if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - was able to reach https://example.com"
    exit 1
else
    echo "Firewall verification passed - unable to reach https://example.com as expected"
fi

# Verify GitHub API access
if ! curl --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - unable to reach https://api.github.com"
    exit 1
else
    echo "Firewall verification passed - able to reach https://api.github.com as expected"
fi
