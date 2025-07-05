# Этот файл включается в install.sh при установке
# Не является самостоятельным скриптом
# Этот файл будет автоматически преобразован при установке

CONFIG_FILE="/etc/ssh_telegram_alert.cfg"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE" || exit 1

IP="${SSH_CLIENT%% *}"
[ -z "$IP" ] && IP="unknown"
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

echo "[$DATE] SSH login: $USER from $IP" >> "/var/log/ssh_telegram_alert.log"