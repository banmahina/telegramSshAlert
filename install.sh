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
echo -e "${YELLOW}=== Установка системы Telegram-уведомлений о SSH-подключениях ===${NC}"
echo

check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}ERROR: Скрипт требует root-прав. Запустите с sudo!${NC}" >&2
    exit 1
  fi
  echo -e "${GREEN}[+] Проверка root-прав выполнена${NC}"
}

install_deps() {
  echo -e "${YELLOW}[.] Установка зависимостей (curl, jq)...${NC}"
  if command -v apt-get &> /dev/null; then
    apt-get update && apt-get install -y curl jq
  elif command -v yum &> /dev/null; then
    yum install -y curl jq
  else
    echo -e "${RED}ERROR: Неизвестный пакетный менеджер. Установите curl и jq вручную.${NC}"
    exit 1
  fi
  echo -e "${GREEN}[+] Зависимости успешно установлены${NC}"
}

validate_token() {
  while true; do
    read -p "$(echo -e "${BLUE}[?] Введите токен Telegram-бота: ${NC}")" BOT_TOKEN
    if [[ "$BOT_TOKEN" =~ ^[0-9]+:[a-zA-Z0-9_-]+$ ]]; then
      break
    else
      echo -e "${RED}ERROR: Неверный формат токена! Пример: 1234567890:ABCdefGHIJKlmNoPQRsTUVwxyZ${NC}"
    fi
  done
}

validate_chat_id() {
  while true; do
    read -p "$(echo -e "${BLUE}[?] Введите chat ID (можно получить через @userinfobot): ${NC}")" CHAT_ID
    if [[ "$CHAT_ID" =~ ^-?[0-9]+$ ]]; then
      break
    else
      echo -e "${RED}ERROR: Chat ID должен содержать только цифры! Пример: 123456789 или -1001234567890${NC}"
    fi
  done
}

get_ssh_port() {
  read -p "$(echo -e "${BLUE}[?] Введите порт SSH (по умолчанию 22): ${NC}")" SSH_PORT
  SSH_PORT=${SSH_PORT:-22}
  echo -e "${GREEN}[+] Используется порт SSH: ${SSH_PORT}${NC}"
}

install_main_script() {
  echo -e "${YELLOW}[.] Установка скрипта уведомлений...${NC}"
  cat > /usr/local/bin/ssh_telegram_alert.sh <<'EOL'
#!/bin/bash

CONFIG_FILE="/etc/ssh_telegram_alert.cfg"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE" || exit 1

IP="unknown"
if [ -n "$SSH_CONNECTION" ]; then
  IP=$(echo "$SSH_CONNECTION" | awk '{print $1}')
elif [ -n "$PAM_RHOST" ]; then
  IP="$PAM_RHOST"
elif command -v who &> /dev/null; then
  IP=$(who -m | awk '{print $NF}' | sed 's/[()]//g')
fi

if [[ "$IP" =~ ^::1$|^127\.|^192\.168\.|^10\.|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-1]\. ]]; then
  IP="local ($IP)"
fi

USER=$(whoami)
HOSTNAME=$(hostname)
DATE=$(date "+%Y-%m-%d %H:%M:%S")

MESSAGE="⚠️ *SSH Alert* ⚠️
• *Server*: \`$HOSTNAME\`
• *User*: \`$USER\`
• *IP*: \`$IP\`
• *Date*: \`$DATE\`"

curl -s -X POST \
  -H 'Content-Type: application/json' \
  -d "{\"chat_id\":\"$CHAT_ID\",\"text\":\"$MESSAGE\",\"parse_mode\":\"markdown\"}" \
  "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" > /dev/null

echo "[$DATE] SSH login: $USER from $IP" >> "$LOG_FILE"
EOL

  chmod 755 /usr/local/bin/ssh_telegram_alert.sh
  echo -e "${GREEN}[+] Скрипт установлен в /usr/local/bin/ssh_telegram_alert.sh${NC}"
}

create_config() {
  echo -e "${YELLOW}[.] Создание конфигурации...${NC}"
  cat > /etc/ssh_telegram_alert.cfg <<EOL
BOT_TOKEN='$BOT_TOKEN'
CHAT_ID='$CHAT_ID'
SSH_PORT='$SSH_PORT'
LOG_FILE='/var/log/ssh_telegram_alert.log'
EOL

  chmod 600 /etc/ssh_telegram_alert.cfg
  echo -e "${GREEN}[+] Конфиг создан в /etc/ssh_telegram_alert.cfg${NC}"
}

setup_pam() {
  echo -e "${YELLOW}[.] Настройка PAM...${NC}"
  if ! grep -q "pam_exec.so.*ssh_telegram_alert" /etc/pam.d/sshd; then
    echo "session optional pam_exec.so seteuid /usr/local/bin/ssh_telegram_alert.sh" >> /etc/pam.d/sshd
    echo -e "${GREEN}[+] PAM успешно настроен${NC}"
  else
    echo -e "${BLUE}[i] PAM уже настроен, пропускаем${NC}"
  fi
}

test_alert() {
  echo -e "${YELLOW}[.] Тестирование системы...${NC}"
  if /usr/local/bin/ssh_telegram_alert.sh; then
    echo -e "${GREEN}[+] Тестовое уведомление отправлено. Проверьте Telegram!${NC}"
  else
    echo -e "${RED}ERROR: Ошибка при отправке тестового уведомления${NC}"
  fi
}

prepare_uninstaller() {
  echo -e "${YELLOW}[.] Настройка скрипта удаления...${NC}"
  if [ -f "$(dirname "$0")/uninstall.sh" ]; then
    chmod +x "$(dirname "$0")/uninstall.sh"
    echo -e "${GREEN}[+] Скрипт удаления готов: $(dirname "$0")/uninstall.sh${NC}"
  else
    echo -e "${RED}ERROR: Файл uninstall.sh не найден в текущей директории${NC}"
  fi
}

main() {
  check_root
  install_deps
  validate_token
  validate_chat_id
  get_ssh_port
  install_main_script
  create_config
  setup_pam
  test_alert
  prepare_uninstaller

  echo -e "\n${GREEN}=============================================="
  echo " Установка успешно завершена!"
  echo "=============================================="
  echo -e "${NC}"
  echo -e "Расположение ключевых файлов:"
  echo -e "• Конфигурация: ${CYAN}/etc/ssh_telegram_alert.cfg${NC}"
  echo -e "• Основной скрипт: ${CYAN}/usr/local/bin/ssh_telegram_alert.sh${NC}"
  echo -e "• Лог-файл: ${CYAN}/var/log/ssh_telegram_alert.log${NC}"
  echo -e "• Скрипт удаления: ${CYAN}$(dirname "$0")/uninstall.sh${NC}"
  echo
  echo -e "Для проверки подключитесь к серверу через SSH"
  echo -e "или выполните: ${CYAN}sudo /usr/local/bin/ssh_telegram_alert.sh${NC}"
}

main