#!/bin/bash

# Айпи игрового сервера
TARGET_IP=""
# Порт игрового сервера
TARGET_PORT=""
# Порт прокси-сервера (должен быть свободен и открыт)
LOCAL_PORT="27015"
BACKUP_FILE="/tmp/iptables_cs2_$(date +%s).dump"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    clear
    echo -e "${CYAN}=======================================================${NC}"
    echo -e "${CYAN}            🛡️  CS2 SERVER PROXY  🛡️               ${NC}"
    echo -e "${CYAN}                    By E!N                             ${NC}"
    echo -e "${CYAN}=======================================================${NC}"
    echo ""
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌  Запустите с правами root (sudo $0)${NC}"
        exit 1
    fi
}

cleanup() {
    echo ""
    echo -e "${YELLOW}🛑  Завершение работы...${NC}"
    if [ -f "$BACKUP_FILE" ]; then
        iptables-restore < "$BACKUP_FILE" && rm -f "$BACKUP_FILE"
    fi
    echo -e "${GREEN}✅  Правила восстановлены. Удачи!${NC}"
    exit 0
}

validate_input() {
    if [[ ! $TARGET_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}❌  Некорректный IP ($TARGET_IP)${NC}"
        exit 1
    fi
    if [[ ! $TARGET_PORT =~ ^[0-9]+$ ]]; then
        echo -e "${RED}❌  Некорректный Порт ($TARGET_PORT)${NC}"
        exit 1
    fi
}

get_public_ip() {
    PUBLIC_IP=$(curl -s --max-time 2 ifconfig.me || ip route get 1 | awk '{print $7;exit}')
    [[ -z "$PUBLIC_IP" ]] && PUBLIC_IP="IP_НЕ_НАЙДЕН"
}

show_dashboard() {
    clear
    print_header
    echo -e "   📍  Прокси:   ${GREEN}$PUBLIC_IP:$LOCAL_PORT${NC}"
    echo -e "   🎯  Игровой сервер:  ${YELLOW}$TARGET_IP:$TARGET_PORT${NC}"
    echo ""
    echo -e "   📋  Подключение: ${GREEN}connect $PUBLIC_IP:$LOCAL_PORT${NC}"
    echo -e "${CYAN}=======================================================${NC}"
    echo -e "   Нажми ${RED}[Enter]${NC} или ${RED}[Ctrl+C]${NC} для выхода."
    read -r
}

check_root
print_header

if [ ! -z "$1" ]; then TARGET_IP=$1; fi
if [ ! -z "$2" ]; then TARGET_PORT=$2; fi

if [ -z "$TARGET_IP" ]; then
    echo -ne "${YELLOW}➡️  IP игрового сервера: ${NC}"
    read TARGET_IP
fi

if [ -z "$TARGET_PORT" ]; then
    echo -ne "${YELLOW}➡️  Порт игрового сервера: ${NC}"
    read TARGET_PORT
fi

validate_input
get_public_ip

iptables-save > "$BACKUP_FILE" || { echo -e "${RED}❌ Ошибка бэкапа${NC}"; exit 1; }

trap cleanup EXIT

echo 1 > /proc/sys/net/ipv4/ip_forward

iptables -t nat -A PREROUTING -p udp --dport $LOCAL_PORT -j DNAT --to-destination $TARGET_IP:$TARGET_PORT
iptables -t nat -A POSTROUTING -p udp -d $TARGET_IP --dport $TARGET_PORT -j MASQUERADE
iptables -t nat -A PREROUTING -p tcp --dport $LOCAL_PORT -j DNAT --to-destination $TARGET_IP:$TARGET_PORT
iptables -t nat -A POSTROUTING -p tcp -d $TARGET_IP --dport $TARGET_PORT -j MASQUERADE

show_dashboard