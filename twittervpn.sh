#!/bin/bash

check_dependencies() {
    local dependencies=("openvpn" "iptables" "ip")
    for dep in "${dependencies[@]}"; do
        if ! command -v $dep &>/dev/null; then
            echo "Dependence not found: $dep. Install it and try again."
            exit 1
        fi
    done
}
check_dependencies

declare -A VPN_CONFIGS
VPN_CONFIGS["vpnbook-ca196-tcp443.ovpn"]="CA1"
VPN_CONFIGS["vpnbook-uk205-tcp443.ovpn"]="UK1"
VPN_CONFIGS["vpnbook-us1-tcp443.ovpn"]="US1"
VPN_CONFIGS["vpnbook-us2-tcp443.ovpn"]="US2"

VPNBOOK_DIR="./vpnbook"
VPN_FILES=("$VPNBOOK_DIR/vpnbook-us1-tcp443.ovpn" "$VPNBOOK_DIR/vpnbook-uk205-tcp443.ovpn" "$VPNBOOK_DIR/vpnbook-ca196-tcp443.ovpn" "$VPNBOOK_DIR/vpnbook-us2-tcp443.ovpn")
CURRENT_VPN_INDEX=0

VPN_USERNAME="vpnbook"
VPN_PASSWORD="b49dzh6"
X_IPS="104.244.42.129 104.244.42.65 104.244.42.193 104.244.42.1"

debug() {
    echo "[DEBUG] $1"
}

cleanup() {
    debug "Terminating actual VPN connection..."
    sudo killall openvpn 2>/dev/null
    while pgrep -x "openvpn" > /dev/null; do
        sleep 1
            debug "Waiting for the OpenVPN processes to finish..."
    done
    debug "VPN connection terminated."
    for IP in $X_IPS; do
        sudo ip route del $IP table 100 2>/dev/null
    done
    sudo iptables -t nat -F
    sudo iptables -F
    for tun_interface in $(ip link show | grep -o "tun[0-9]"); do
        sudo ip link delete $tun_interface 2>/dev/null
    done
    debug "Cleanup completed."
}

find_available_tun() {
    local tun_number=0
    while ip link show "tun${tun_number}" &>/dev/null; do
        tun_number=$((tun_number + 1))
    done
    echo "tun${tun_number}"
}

connect_vpn() {
    VPN_CONFIG="${VPN_FILES[$CURRENT_VPN_INDEX]}"
    debug "VPN connection with $VPN_CONFIG..."
    VPN_AUTH_FILE=$(mktemp /tmp/vpn-auth.XXXXXX)
    echo -e "${VPN_USERNAME}\n${VPN_PASSWORD}" > $VPN_AUTH_FILE
    chmod 600 $VPN_AUTH_FILE
    VPN_TEMP_CONFIG=$(mktemp /tmp/vpn-temp.XXXXXX)
    sed '/redirect-gateway/d; /dhcp-option/d; /route/d' "$VPN_CONFIG" > $VPN_TEMP_CONFIG
    echo "route-nopull" >> $VPN_TEMP_CONFIG
    echo "comp-lzo no" >> $VPN_TEMP_CONFIG
    echo "auth-nocache" >> $VPN_TEMP_CONFIG
    VPN_INTERFACE=$(find_available_tun)
    debug "Using Interface VPN: $VPN_INTERFACE"
    sudo openvpn --config $VPN_TEMP_CONFIG --auth-user-pass $VPN_AUTH_FILE --daemon --log-append vpn.log --verb 4 --dev $VPN_INTERFACE
    if [[ $? -ne 0 ]]; then
        debug "Error to start OpenVPN."
        exit 1
    fi
    debug "Waiting VPN interface to be up..."
    TIMEOUT=30
    COUNTER=0
    while ! ip link show $VPN_INTERFACE &> /dev/null; do
        sleep 1
        COUNTER=$((COUNTER + 1))
        debug "Waiting tun interface to be up..."
        if [[ $COUNTER -ge $TIMEOUT ]]; then
            debug "Time limit exceeded. Exiting..."
            cleanup
            return 1
        fi
    done
    sudo ip route del 0.0.0.0/1 dev $VPN_INTERFACE 2>/dev/null && debug "Route 0.0.0.0/1 removed."
    sudo ip route del 128.0.0.0/1 dev $VPN_INTERFACE 2>/dev/null && debug "Route 128.0.0.0/1 removed."
    rm $VPN_AUTH_FILE $VPN_TEMP_CONFIG
    debug "VPN connection established with $VPN_CONFIG"
    for IP in $X_IPS; do
        sudo ip route add $IP dev $VPN_INTERFACE table 100
        sudo iptables -t mangle -A OUTPUT -d $IP -j MARK --set-mark 100
        sudo iptables -t mangle -A PREROUTING -s $IP -m conntrack --ctstate RELATED,ESTABLISHED -j MARK --set-mark 100
    done
    sudo ip rule add fwmark 100 table 100
    sudo ip route add default via $(ip route show | awk '/default/ {print $3}') dev $(ip route show | awk '/default/ {print $5}')
    sudo iptables -t nat -A POSTROUTING -o $VPN_INTERFACE -j MASQUERADE
}

while true; do
    cleanup
    connect_vpn
    sleep 1800
    CURRENT_VPN_INDEX=$(( (CURRENT_VPN_INDEX + 1) % ${#VPN_FILES[@]} ))
    debug "Alternating to the next VPN server..."
done
