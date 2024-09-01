#!/bin/bash

# Nome do arquivo de log
LOGFILE="vpn_diagnostics.log"

# Iniciar novo arquivo de log
echo "Iniciando diagnósticos VPN em $(date)" > $LOGFILE

# Verificar dependências
echo "Verificando dependências..." >> $LOGFILE
dependencies=("openvpn" "iptables" "ip" "dig" "traceroute" "tcpdump" "curl")
for dep in "${dependencies[@]}"; do
    if ! command -v $dep &>/dev/null; then
        echo "Dependência não encontrada: $dep." >> $LOGFILE
    else
        echo "Dependência encontrada: $dep." >> $LOGFILE
    fi
done

# Resolver IPs para x.com
echo "Resolvendo IPs para x.com..." >> $LOGFILE
IPs=$(dig x.com +short)
echo "IPs encontrados: $IPs" >> $LOGFILE

# Verificar rotas para IPs de x.com
echo "Verificando rotas para IPs de x.com..." >> $LOGFILE
for IP in $IPs; do
    echo "Rota para $IP:" >> $LOGFILE
    ip route get $IP >> $LOGFILE
done

# Traceroute para IPs de x.com
echo "Executando traceroute para IPs de x.com..." >> $LOGFILE
for IP in $IPs; do
    echo "Traceroute para $IP:" >> $LOGFILE
    traceroute $IP >> $LOGFILE
done

# Verificar regras de IPTables
echo "Verificando regras de IPTables..." >> $LOGFILE
sudo iptables -t mangle -L -v >> $LOGFILE

# Monitorar o tráfego da VPN com tcpdump (captura limitada a 10 pacotes para exemplo)
echo "Monitorando o tráfego da VPN..." >> $LOGFILE
sudo tcpdump -i tun0 host $IPs -c 10 >> $LOGFILE

# Verificar status do OpenVPN
echo "Verificando status do OpenVPN..." >> $LOGFILE
pgrep -a openvpn >> $LOGFILE

# Testar acesso direto a x.com
echo "Testando acesso HTTP e HTTPS direto para x.com..." >> $LOGFILE
curl -v http://x.com >> $LOGFILE 2>&1
curl -v https://x.com >> $LOGFILE 2>&1

echo "Diagnósticos completados. Por favor, revise o arquivo $LOGFILE para mais detalhes." >> $LOGFILE
