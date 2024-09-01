#!/bin/bash

# Verifica se um argumento foi fornecido
if [ $# -eq 0 ]; then
    echo "Por favor, forneça um argumento de estágio: 'normal', 'nordvpn' ou 'nordvpn_openvpn'"
    exit 1
fi

# Define o arquivo de log com base no estágio fornecido
LOGFILE="vpn_diagnostics_$1.log"

echo "Iniciando diagnósticos VPN em $(date) para o estágio $1" | tee $LOGFILE

echo "Verificando dependências..." | tee -a $LOGFILE
dependencies=("openvpn" "iptables" "ip" "dig" "traceroute" "tcpdump" "curl")
for dep in "${dependencies[@]}"; do
    echo "Checando $dep..." | tee -a $LOGFILE
    if ! command -v $dep &>/dev/null; then
        echo "Dependência não encontrada: $dep." | tee -a $LOGFILE
    else
        echo "Dependência encontrada: $dep." | tee -a $LOGFILE
    fi
done

echo "Resolvendo IPs para x.com..." | tee -a $LOGFILE
IPs=$(dig x.com +short)
echo "IPs encontrados: $IPs" | tee -a $LOGFILE

echo "Verificando rotas para IPs de x.com..." | tee -a $LOGFILE
for IP in $IPs; do
    echo "Rota para $IP:" | tee -a $LOGFILE
    ip route get $IP | tee -a $LOGFILE
done

echo "Executando traceroute para IPs de x.com..." | tee -a $LOGFILE
for IP in $IPs; do
    echo "Traceroute para $IP:" | tee -a $LOGFILE
    traceroute $IP | tee -a $LOGFILE
done

echo "Verificando regras de IPTables..." | tee -a $LOGFILE
sudo iptables -t mangle -L -v | tee -a $LOGFILE

# Verifica se está no estágio com VPN para capturar tráfego com tcpdump
if [ "$1" = "nordvpn_openvpn" ]; then
    echo "Monitorando o tráfego da VPN..." | tee -a $LOGFILE
    sudo tcpdump -i tun0 host $IPs -c 10 | tee -a $LOGFILE
fi

echo "Verificando status do OpenVPN..." | tee -a $LOGFILE
pgrep -a openvpn | tee -a $LOGFILE

echo "Testando acesso HTTP e HTTPS direto para x.com..." | tee -a $LOGFILE
curl -v http://x.com | tee -a $LOGFILE 2>&1
curl -v https://x.com | tee -a $LOGFILE 2>&1

echo "Diagnósticos para $1 completados. Por favor, revise o arquivo $LOGFILE para mais detalhes." | tee -a $LOGFILE
