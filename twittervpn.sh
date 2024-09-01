#!/bin/bash

# Verificação de dependências
check_dependencies() {
    local dependencies=("openvpn" "iptables" "ip")
    for dep in "${dependencies[@]}"; do
        if ! command -v $dep &>/dev/null; then
            echo "Dependência não encontrada: $dep. Instale-a e tente novamente."
            exit 1
        fi
    done
}
check_dependencies

# Configurações da VPN
declare -A VPN_CONFIGS
VPN_CONFIGS["vpnbook-ca196-tcp443.ovpn"]="CA1"
VPN_CONFIGS["vpnbook-uk205-tcp443.ovpn"]="UK1"
VPN_CONFIGS["vpnbook-us1-tcp443.ovpn"]="US1"
VPN_CONFIGS["vpnbook-us2-tcp443.ovpn"]="US2"

# Lista de arquivos de configuração (paths)
VPNBOOK_DIR="./vpnbook"  # Diretório onde estão os arquivos .ovpn
VPN_FILES=("$VPNBOOK_DIR/vpnbook-us1-tcp443.ovpn" "$VPNBOOK_DIR/vpnbook-uk205-tcp443.ovpn" "$VPNBOOK_DIR/vpnbook-ca196-tcp443.ovpn" "$VPNBOOK_DIR/vpnbook-us2-tcp443.ovpn")
CURRENT_VPN_INDEX=0

# Configurações básicas da VPN
VPN_USERNAME="vpnbook"
VPN_PASSWORD="b49dzh6"
TWITTER_IPS=("104.244.42.0/24" "199.16.156.0/22" "199.59.148.0/22" "8.25.194.0/23" "8.25.196.0/23" "204.92.114.203" "204.92.114.204/31")

# Função para exibir mensagens de depuração
debug() {
    echo "[DEBUG] $1"
}

# Limpar configuração de VPN antiga e liberar interfaces TUN
cleanup() {
    debug "Terminando conexão VPN atual..."
    sudo killall openvpn 2>/dev/null
    debug "Conexão VPN terminada."
    
    # Remover rotas de Twitter
    for IP in "${TWITTER_IPS[@]}"; do
        sudo ip route del $IP table 100 2>/dev/null
    done
    
    # Limpar regras do iptables
    sudo iptables -t nat -F
    sudo iptables -F

    # Limpar interfaces TUN ocupadas
    for tun_interface in $(ip link show | grep -o "tun[0-9]"); do
        sudo ip link delete $tun_interface 2>/dev/null
    done

    debug "Limpeza concluída."
}

# Detectar interface TUN disponível
find_available_tun() {
    local tun_number=0
    while ip link show "tun${tun_number}" &>/dev/null; do
        tun_number=$((tun_number + 1))
    done
    echo "tun${tun_number}"
}

# Conectar à VPN usando OpenVPN
connect_vpn() {
    VPN_CONFIG="${VPN_FILES[$CURRENT_VPN_INDEX]}"
    debug "Iniciando conexão VPN com $VPN_CONFIG..."

    # Criar arquivo de autenticação temporário
    VPN_AUTH_FILE=$(mktemp /tmp/vpn-auth.XXXXXX)
    echo -e "${VPN_USERNAME}\n${VPN_PASSWORD}" > $VPN_AUTH_FILE
    chmod 600 $VPN_AUTH_FILE  # Configura as permissões de arquivo corretas

    # Modificar o arquivo de configuração VPN temporário
    VPN_TEMP_CONFIG=$(mktemp /tmp/vpn-temp.XXXXXX)
    sed '/redirect-gateway/d; /dhcp-option/d; /route/d' "$VPN_CONFIG" > $VPN_TEMP_CONFIG
    echo "route-nopull" >> $VPN_TEMP_CONFIG  # Evita puxar as rotas padrão do servidor
    echo "comp-lzo no" >> $VPN_TEMP_CONFIG  # Desativa compressão
    echo "auth-nocache" >> $VPN_TEMP_CONFIG  # Evita caching de senha

    # Detectar interface TUN disponível
    VPN_INTERFACE=$(find_available_tun)
    debug "Usando interface VPN: $VPN_INTERFACE"

    # Iniciar OpenVPN
    sudo openvpn --config $VPN_TEMP_CONFIG --auth-user-pass $VPN_AUTH_FILE --daemon --log-append vpn.log --verb 4 --dev $VPN_INTERFACE
    if [[ $? -ne 0 ]]; then
        debug "Erro ao iniciar o OpenVPN."
        exit 1
    fi

    # Verifica se a interface da VPN está ativa
    debug "Esperando a interface VPN ser ativada..."
    TIMEOUT=30  # Tempo máximo de espera em segundos
    COUNTER=0

    while ! ip link show $VPN_INTERFACE &> /dev/null; do
        sleep 1
        COUNTER=$((COUNTER + 1))
        debug "Esperando a interface VPN ser ativada..."
        if [[ $COUNTER -ge $TIMEOUT ]]; then
            debug "Tempo limite alcançado ao esperar pela interface VPN. Tentando novamente..."
            cleanup
            return 1  # Retornar código de erro
        fi
    done

    # Remover rotas indesejadas que o servidor VPN pode ter adicionado
    sudo ip route del 0.0.0.0/1 dev $VPN_INTERFACE 2>/dev/null
    sudo ip route del 128.0.0.0/1 dev $VPN_INTERFACE 2>/dev/null

    # Remover arquivos temporários
    rm $VPN_AUTH_FILE $VPN_TEMP_CONFIG

    debug "Conexão VPN estabelecida com $VPN_CONFIG."

    # Adicionar rotas para o Twitter através da VPN
    for IP in "${TWITTER_IPS[@]}"; do
        sudo ip route add $IP dev $VPN_INTERFACE table 100
    done

    # Marcar pacotes para o tráfego de saída de twitter.com e x.com
    for IP in "${TWITTER_IPS[@]}"; do
        sudo iptables -t mangle -A OUTPUT -d $IP -j MARK --set-mark 100
    done

    # Regras de roteamento para o tráfego marcado
    sudo ip rule add fwmark 100 table 100
}

# Loop para alternar VPNs a cada 30 minutos
while true; do
    # Limpar a conexão atual antes de mudar
    cleanup

    # Conectar à VPN
    connect_vpn

    # Aguardar 30 minutos
    sleep 1800

    # Atualizar o índice para a próxima configuração de VPN
    CURRENT_VPN_INDEX=$(( (CURRENT_VPN_INDEX + 1) % ${#VPN_FILES[@]} ))

    # Informações adicionais podem ser mostradas aqui se necessário
    debug "Alternando para a próxima configuração de VPN..."
done
