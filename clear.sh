#!/bin/bash

# Nome da interface VPN que você usou (ajuste conforme necessário)
VPN_INTERFACE="tun0"

echo "Limpando as configurações de VPN e rede..."

# Matar processos do OpenVPN
echo "Terminando todos os processos OpenVPN..."
sudo killall openvpn

# Remover as rotas IP específicas para x.com
echo "Removendo rotas IP específicas..."
IPs=$(dig x.com +short)  # Obtém os IPs atuais de x.com
for IP in $IPs; do
    sudo ip route del $IP dev $VPN_INTERFACE table 100 2>/dev/null
done

# Limpar as regras do iptables
echo "Limpando regras do iptables..."
sudo iptables -t nat -F
sudo iptables -t mangle -F

# Remover regras de marcação e roteamento
sudo ip rule del fwmark 100 table 100

# Desativar interfaces de tunelamento, se necessário
echo "Desativando interfaces de tunelamento..."
for tun in $(ip link show | grep -o "tun[0-9]+"); do
    sudo ip link delete $tun
done

echo "Configurações de rede limpas e restauradas ao estado original."
