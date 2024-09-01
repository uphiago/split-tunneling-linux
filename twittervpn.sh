#!/bin/bash

check_dependencies() {
    local dependencies=("openvpn" "iptables" "ip" "dig")
    for dep in "${dependencies[@]}"; do
        if ! command -v $dep &>/dev/null; then
            echo "Dependência não encontrada: $dep. Instale-a e tente novamente."
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
X_IPS=$(dig x.com +short)

debug() {
    echo "[DEBUG] $1"
}

cleanup() {
    debug "Terminando conexão VPN atual..."
    sudo killall openvpn 2>/dev/null
    while pgrep -x "openvpn" > /dev/null; do
        sleep 1
        debug "Esperando os processos do OpenVPN terminarem..."
    done
    debug "Conexão VPN terminada."
    for IP in $X_IPS; do
        sudo ip route del $IP table 100 2>/dev/null
    done
    sudo iptables -t nat -F
    sudo iptables -F
    for tun_interface in $(ip link show | grep -o "tun[0-9]"); do
        sudo ip link delete $tun_interface 2>/dev/null
    done
    debug "Limpeza concluída."
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
    debug "Iniciando conexão VPN com $VPN_CONFIG..."
    VPN_AUTH_FILE=$(mktemp /tmp/vpn-auth.XXXXXX)
    echo -e "${VPN_USERNAME}\n${VPN_PASSWORD}" > $VPN_AUTH_FILE
    chmod 600 $VPN_AUTH_FILE
    VPN_TEMP_CONFIG=$(mktemp /tmp/vpn-temp.XXXXXX)
    sed '/redirect-gateway/d; /dhcp-option/d; /route/d' "$VPN_CONFIG" > $VPN_TEMP_CONFIG
    echo "route-nopull" >> $VPN_TEMP_CONFIG
    echo "comp-lzo no" >> $VPN_TEMP_CONFIG
    echo "auth-nocache" >> $VPN_TEMP_CONFIG
    VPN_INTERFACE=$(find_available_tun)
    debug "Usando interface VPN: $VPN_INTERFACE"
    sudo openvpn --config $VPN_TEMP_CONFIG --auth-user-pass $VPN_AUTH_FILE --daemon --log-append vpn.log --verb 4 --dev $VPN_INTERFACE
    if [[ $? -ne 0 ]]; then
        debug "Erro ao iniciar o OpenVPN."
        exit 1
    fi
    debug "Esperando a interface VPN ser ativada..."
    TIMEOUT=30
    COUNTER=0
    while ! ip link show $VPN_INTERFACE &> /dev/null; do
        sleep 1
        COUNTER=$((COUNTER + 1))
        debug "Esperando a interface VPN ser ativada..."
        if [[ $COUNTER -ge $TIMEOUT ]]; then
            debug "Tempo limite alcançado ao esperar pela interface VPN. Tentando novamente..."
            cleanup
            return 1
        fi
    done
    sudo ip route del 0.0.0.0/1 dev $VPN_INTERFACE 2>/dev/null && debug "Rota 0.0.0.0/1 removida."
    sudo ip route del 128.0.0.0/1 dev $VPN_INTERFACE 2>/dev/null && debug "Rota 128.0.0.0/1 removida."
    rm $VPN_AUTH_FILE $VPN_TEMP_CONFIG
    debug "Conexão VPN estabelecida com $VPN_CONFIG."
    for IP in $X_IPS; do
        sudo ip route add $IP dev $VPN_INTERFACE table 100
        sudo iptables -t mangle -A OUTPUT -d $IP -j MARK --set-mark 100
        sudo iptables -t mangle -A PREROUTING -s $IP -m conntrack --ctstate RELATED,ESTABLISHED -j MARK --set-mark 100
    done
    sudo ip rule add fwmark 100 table 100
    sudo iptables -t mangle -A POSTROUTING -j CONNMARK --save-mark
    sudo iptables -t mangle -A POSTROUTING -m mark ! --mark 100 -j MARK --set-mark 0
}

while true; do
    cleanup
    connect_vpn
    sleep 1800
    CURRENT_VPN_INDEX=$(( (CURRENT_VPN_INDEX + 1) % ${#VPN_FILES[@]} ))
    debug "Alternando para a próxima configuração de VPN..."
done
