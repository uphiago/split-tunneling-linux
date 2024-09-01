#!/bin/bash

VPN_INTERFACE="tun0"

echo "Limpando as configurações de VPN e rede..."

echo "Terminando todos os processos OpenVPN..."
sudo killall openvpn

echo "Removendo rotas IP específicas..."
IPs=$(dig x.com +short)
for IP in $IPs; do
    sudo ip route del $IP dev $VPN_INTERFACE table 100 2>/dev/null
done

echo "Limpando regras do iptables..."
sudo iptables -t nat -F
sudo iptables -t mangle -F

sudo ip rule del fwmark 100 table 100

echo "Desativando interfaces de tunelamento..."
for tun in $(ip link show | grep -o "tun[0-9]+"); do
    sudo ip link delete $tun
done

echo "Configurações de rede limpas e restauradas ao estado original."
