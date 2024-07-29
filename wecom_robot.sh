#!/bin/bash

# 定义 keys.json 文件路径
KEYS_FILE="keys.json"

# 检查 keys.json 文件是否存在，如果不存在则使用一个空的 JSON 对象
if [ ! -f "$KEYS_FILE" ]; then
  KEYS_JSON='{}'
else
  KEYS_JSON=$(cat "$KEYS_FILE")
fi

# 检查输入参数数量
MIN_ARGS=3
if [ "$#" -lt "$MIN_ARGS" ]; then
  echo "使用方法: $0 <key_identifier|--all> <message_type> [其他参数...]"
  exit 1
fi

# 获取 key 标识和消息类型
KEY_IDENTIFIER=$1
MESSAGE_TYPE=$2
shift 2

# 定义函数，根据消息类型调用 send_message.sh
send_message() {
  local KEY=$1
  local MESSAGE_TYPE=$2
  shift 2

  if [ -n "$KEY" ]; then
    KEY_OPTION="-k $KEY"
  else
    KEY_OPTION=""
  fi

  case $MESSAGE_TYPE in
    text)
      ./send_message.sh $KEY_OPTION text "$@"
      ;;
    markdown)
      ./send_message.sh $KEY_OPTION markdown "$@"
      ;;
    news)
      ./send_message.sh $KEY_OPTION news "$@"
      ;;
    file)
      ./send_message.sh $KEY_OPTION file "$@"
      ;;
    voice)
      ./send_message.sh $KEY_OPTION voice "$@"
      ;;
    image)
      ./send_message.sh $KEY_OPTION image "$@"
      ;;
    *)
      echo "未知的消息类型: $MESSAGE_TYPE"
      exit 1
      ;;
  esac
}

if [ "$KEY_IDENTIFIER" == "--all" ]; then
  # 获取所有 keys
  KEYS=$(echo "$KEYS_JSON" | jq -r 'keys[]')

  # 循环发送消息
  for key in $KEYS; do
    # 获取每个 key 的值，如果 key 不存在则返回空字符串
    KEY=$(echo "$KEYS_JSON" | jq -r --arg key "$key" '.[$key] // empty')

    if [ -z "$KEY" ]; then
      echo "标识符不存在: $key，使用默认的 key。"
      KEY=""
    fi

    send_message "$KEY" "$MESSAGE_TYPE" "$@"
  done
else
  # 获取单个 key
  KEY=$(echo "$KEYS_JSON" | jq -r --arg key "$KEY_IDENTIFIER" '.[$key] // empty')

  if [ -z "$KEY" ]; then
    echo "标识符不存在: $KEY_IDENTIFIER，使用默认的 key。"
    KEY=""
  fi

  send_message "$KEY" "$MESSAGE_TYPE" "$@"
fi
