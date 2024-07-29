#!/bin/bash

# wecom_robot.sh
# 企业微信机器人消息发送脚本
#
# 作者: Ivan Zhang
# 日期: 2024/07/29
#
# 描述:
# 该脚本读取 keys.json 文件中的 webhook keys，根据指定的 key 标识符或发送到所有 keys。
# 支持发送多种类型的消息（text, markdown, news, file, voice, image）。
# 如果指定的 key 不存在，则会输出错误信息并退出。
# 当使用 --all 参数时，会发送消息到所有的 keys。

# 定义 keys.json 文件路径
KEYS_FILE="keys.json"

# 读取或初始化 keys.json
load_keys_json() {
  if [ ! -f "$KEYS_FILE" ]; then
    echo '{}'
  else
    cat "$KEYS_FILE"
  fi
}

# 检查输入参数数量
check_args() {
  local MIN_ARGS=3
  if [ "$#" -lt "$MIN_ARGS" ]; then
    echo "使用方法: $0 <key_identifier|--all> <message_type> [其他参数...]"
    exit 1
  fi
}

# 定义函数，根据消息类型调用 send_message.sh
send_message() {
  local KEY=$1
  local MESSAGE_TYPE=$2
  shift 2

  if [ -n "$KEY" ]; then
    local KEY_OPTION="-k $KEY"
  else
    local KEY_OPTION=""
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

# 检查单个 key 是否存在于 JSON 中
check_key_exists() {
  local KEYS_JSON=$1
  local KEY=$2
  echo $(echo "$KEYS_JSON" | jq -r --arg key "$KEY" '.[$key] // empty')
}

# 处理所有 keys 的情况
process_all_keys() {
  local KEYS_JSON=$1
  local MESSAGE_TYPE=$2
  shift 2

  local KEYS=$(echo "$KEYS_JSON" | jq -r 'keys[]')
  local MISSING_KEYS=()
  local VALID_KEYS=()

  for key in $KEYS; do
    local VALUE=$(check_key_exists "$KEYS_JSON" "$key")
    if [ -z "$VALUE" ]; then
      MISSING_KEYS+=("$key")
    else
      VALID_KEYS+=("$VALUE")
    fi
  done

  # 如果存在缺失的 key，输出错误信息并退出
  if [ ${#MISSING_KEYS[@]} -ne 0 ]; then
    echo "以下标识符不存在: ${MISSING_KEYS[*]}"
    exit 1
  fi

  # 发送消息到所有有效的 keys
  for key in "${VALID_KEYS[@]}"; do
    send_message "$key" "$MESSAGE_TYPE" "$@"
  done
}

# 处理指定的多个 keys 的情况
process_multiple_keys() {
  local KEYS_JSON=$1
  local KEY_IDENTIFIER=$2
  local MESSAGE_TYPE=$3
  shift 3

  IFS=',' read -r -a KEY_ARRAY <<< "$KEY_IDENTIFIER"
  local MISSING_KEYS=()
  local VALID_KEYS=()

  for key in "${KEY_ARRAY[@]}"; do
    local VALUE=$(check_key_exists "$KEYS_JSON" "$key")
    if [ -z "$VALUE" ]; then
      MISSING_KEYS+=("$key")
    else
      VALID_KEYS+=("$VALUE")
    fi
  done

  # 如果存在缺失的 key，输出错误信息并退出
  if [ ${#MISSING_KEYS[@]} -ne 0 ]; then
    echo "以下标识符不存在: ${MISSING_KEYS[*]}"
    exit 1
  fi

  # 发送消息到所有有效的 keys
  for key in "${VALID_KEYS[@]}"; do
    send_message "$key" "$MESSAGE_TYPE" "$@"
  done
}

# 主逻辑
main() {
  # 加载 keys.json 文件
  local KEYS_JSON=$(load_keys_json)

  # 检查传入参数数量
  check_args "$@"

  # 获取 key 标识符和消息类型
  local KEY_IDENTIFIER=$1
  local MESSAGE_TYPE=$2
  shift 2

  # 根据 key 标识符处理不同情况
  if [ "$KEY_IDENTIFIER" == "--all" ]; then
    process_all_keys "$KEYS_JSON" "$MESSAGE_TYPE" "$@"
  else
    process_multiple_keys "$KEYS_JSON" "$KEY_IDENTIFIER" "$MESSAGE_TYPE" "$@"
  fi
}

# 脚本入口点
main "$@"
