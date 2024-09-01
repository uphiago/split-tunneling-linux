#!/bin/bash

# Nome do arquivo de log
LOGFILE="vpn_diagnostics.log"

# Iniciar novo arquivo de log
echo "Iniciando diagnósticos VPN em $(date)" | tee $LOGFILE

# Verificar dependências
echo "Verificando dependências..." | tee -a $LOGFILE
dependencies=("openvpn" "iptables" "ip" "dig" "traceroute" "tcpdump" "curl")
for dep in "${dependencies[@]}"; do
    if ! command -v $dep &>/dev/null; then
        echo "Dependência não encontrada: $dep." | tee -a $LOGFILE
    else
        echo "Dependência encontrada: $dep." | tee -a $LOGFILE
    fi
done

# Resolver IPs para x.com
echo "Resolvendo IPs para x.com..." | tee -a $LOGFILE
IPs=$(dig x.com +short)
echo "IPs encontrados: $IPs" | tee -a $LOGFILE

# Verificar rotas para IPs de x.com
echo "Verificando rotas para IPs de x.com..." | tee -a $LOGFILE
for IP in $IPs; do
    echo "Rota para $IP:" | tee -a $LOGFILE
    ip route get $IP | tee -a $LOGFILE
done

# Traceroute para IPs de x.com
echo "Executando traceroute para IPs de x.com..." | tee -a $LOGFILE
for IP in $IPs; do
    echo "Traceroute para $IP:" | tee -a $LOGFILE
    traceroute $IP | tee -a $LOGFILE
done

# Verificar regras de IPTables
echo "Verificando regras de IPTables..." | tee -a $LOGFILE
sudo iptables -t mangle -L -v | tee -a $LOGFILE

# Monitorar o tráfego da VPN com tcpdump (captura limitada a 10 pacotes para exemplo)
echo "Monitorando o tráfego da VPN..." | tee -a $LOGFILE
sudo tcpdump -i tun0 host $IPs -c 10 | tee -a $LOGFILE

# Verificar status do OpenVPN
echo "Verificando status do OpenVPN..." | tee -a $LOGFILE
pgrep -a openvpn | tee -a $LOGFILE

# Testar acesso direto a x.com
echo "Testando acesso HTTP e HTTPS direto para x.com..." | tee -a $LOGFILE
curl -v http://x.com >> $LOGFILE 2>&1 | tee -a $LOGFILE
curl -v https://x.com >> $LOGFILE 2>&1 | tee -a $LOGFILE

echo "Diagnósticos completados. Por favor, revise o arquivo $LOGFILE para mais detalhes." | tee -a $LOGFILE
