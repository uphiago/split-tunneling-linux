#!/bin/bash

LOGFILE="vpn_diagnostics.log"

echo "Iniciando diagnósticos VPN em $(date)" | tee $LOGFILE

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

echo "Monitorando o tráfego da VPN..." | tee -a $LOGFILE
sudo tcpdump -i tun0 host $IPs -c 10 | tee -a $LOGFILE

echo "Verificando status do OpenVPN..." | tee -a $LOGFILE
pgrep -a openvpn | tee -a $LOGFILE

echo "Testando acesso HTTP e HTTPS direto para x.com..." | tee -a $LOGFILE
