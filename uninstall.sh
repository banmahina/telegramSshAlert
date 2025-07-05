#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
  _____   _____  _    _            _       ______  _____   _______ 
 / ____| / ____|| |  | |    /\    | |     |  ____||  __ \ |__   __|
| (___  | (___  | |__| |   /  \   | |     | |__   | |__) |   | |
 \___ \  \___ \ |  __  |  / /\ \  | |     |  __|  |  _  /    | |
 ____) | ____) || |  | | / ____ \ | |____ | |____ | | \ \    | |
|_____/ |_____/ |_|  |_|/_/    \_\|______||______||_|  \_\   |_|  
EOF
echo -e "${NC}"
echo -e "${YELLOW}=== Удаление системы SSH Telegram Alert ===${NC}"
echo

if [ "$(id -u)" -ne 0 ]; then
  echo -e "${RED}ERROR: Требуются root-права! Используйте sudo.${NC}" >&2
  exit 1
fi

remove_component() {
  local path="$1"
  local name="$2"
  
  if [ -f "$path" ] || [ -d "$path" ]; then
    rm -rf "$path"
    echo -e "${GREEN}[+] Удалено: ${name}${NC}"
  else
    echo -e "${BLUE}[-] Не найден: ${name}${NC}"
  fi
}

echo -e "${YELLOW}[.] Начало удаления...${NC}"

if grep -q "pam_exec.so.*ssh_telegram_alert" /etc/pam.d/sshd; then
  sed -i '/pam_exec.so.*ssh_telegram_alert/d' /etc/pam.d/sshd
  echo -e "${GREEN}[+] Удалена запись из /etc/pam.d/sshd${NC}"
else
  echo -e "${BLUE}[-] Запись в PAM не найдена${NC}"
fi

remove_component "/usr/local/bin/ssh_telegram_alert.sh" "Основной скрипт"
remove_component "/etc/ssh_telegram_alert.cfg" "Конфигурация"
remove_component "/var/log/ssh_telegram_alert.log" "Лог-файл"

if [ -f "/etc/systemd/system/ssh-telegram-alert.service" ]; then
  systemctl stop ssh-telegram-alert.service
  systemctl disable ssh-telegram-alert.service
  rm -f "/etc/systemd/system/ssh-telegram-alert.service"
  echo -e "${GREEN}[+] Удален systemd сервис${NC}"
fi

echo -e "\n${GREEN}=============================================="
echo " Система SSH Telegram Alert полностью удалена!"
echo "=============================================="
echo -e "${NC}"
echo -e "Для применения изменений может потребоваться:"
echo -e "${CYAN}systemctl daemon-reload${NC}"
echo -e "${CYAN}service sshd restart${NC}"