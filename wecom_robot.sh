#!/bin/bash
# -*- coding: utf-8 -*-

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
#
# 更新日志:
#
# 2024/07/29
#   1. 初始版本
# 2026/06/04
#   1. 添加完整的函数注释
#   2. 增强错误处理机制
#   3. 优化参数验证逻辑
#   4. 添加统计信息输出
#   5. 支持默认配置回退机制

# 定义 keys.json 文件路径
KEYS_FILE="keys.json"

# 打印使用帮助
# 功能: 显示脚本的使用说明和示例
# 参数: 无
# 返回值: 无，直接退出脚本
print_usage() {
    echo "企业微信机器人消息发送脚本"
    echo ""
    echo "使用方法: $0 <key_identifier|--all> <message_type> [其他参数...]"
    echo ""
    echo "参数说明:"
    echo "  <key_identifier>   keys.json 中的 key 标识符，多个标识符用逗号分隔"
    echo "                    例如: 'group1' 或 'group1,group2,group3'"
    echo "  --all              发送消息到所有配置的 key"
    echo "  <message_type>     消息类型: text, markdown, news, file, voice, image"
    echo ""
    echo "消息类型参数:"
    echo "  text:     <content> [mentioned_list] [mentioned_mobile_list]"
    echo "  markdown: <content>"
    echo "  news:     <titles> [descriptions] <urls> [picurls]"
    echo "  file:     <file_path>"
    echo "  voice:    <file_path>"
    echo "  image:    <image_path_or_base64>"
    echo ""
    echo "示例:"
    echo "  $0 group1 text '测试消息'"
    echo "  $0 group1,group2 markdown '# 标题\\n内容'"
    echo "  $0 --all text '全体通知'"
    echo "  $0 group1 file '/path/to/file.txt'"
    exit 0
}

# 打印版本信息
# 功能: 显示脚本的版本信息
# 参数: 无
# 返回值: 无，直接退出脚本
print_version() {
    echo "wecom_robot.sh v1.0.0"
    echo "企业微信机器人消息发送脚本"
    echo "基于 send_message.sh 封装，支持批量消息发送"
    exit 0
}

# 检查必要依赖
# 功能: 检查运行脚本所需的外部依赖命令
# 参数: 无
# 返回值: 0 - 所有依赖都存在，1 - 有缺失的依赖
check_dependencies() {
    local missing_deps=()
    
    # 检查jq
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi
    
    # 检查send_message.sh
    if [ ! -x "./send_message.sh" ]; then
        echo "错误: send_message.sh 不存在或不可执行"
        echo "请确保 send_message.sh 在当前目录下并具有可执行权限"
        exit 1
    fi
    
    # 如果有缺失的依赖
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "错误: 缺少必要的依赖命令: ${missing_deps[*]}"
        echo "请安装缺失的命令后再运行此脚本。"
        exit 1
    fi
    
    return 0
}

# 读取或初始化 keys.json
# 功能: 读取 keys.json 配置文件，如果文件不存在或为空则返回空 JSON 对象
# 参数: 无
# 返回值: keys.json 文件内容或空 JSON 对象
load_keys_json() {
    if [ ! -f "$KEYS_FILE" ]; then
        echo "警告: keys.json 文件不存在，将使用默认配置" >&2
        echo '{}'
        return
    fi
    
    # 检查 keys.json 是否为空
    if [ ! -s "$KEYS_FILE" ]; then
        echo "警告: $KEYS_FILE 文件为空，将使用默认配置" >&2
        echo '{}'
        return
    fi
    
    cat "$KEYS_FILE"
}

# 检查输入参数数量
# 功能: 验证脚本输入参数的数量
# 参数: 脚本的所有输入参数
# 返回值: 无，参数不足时显示使用帮助并退出
check_args() {
    if [ "$#" -eq 0 ]; then
        print_usage
    fi
    
    # 处理帮助和版本参数
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        print_usage
    fi
    
    if [ "$1" = "--version" ] || [ "$1" = "-v" ]; then
        print_version
    fi
    
    local MIN_ARGS=2
    if [ "$#" -lt "$MIN_ARGS" ]; then
        echo "错误: 参数不足" >&2
        echo "" >&2
        print_usage
    fi
}

# 检查单个 key 是否存在于 JSON 中
# 功能: 检查指定的 key 标识符是否存在于 keys.json 中
# 参数: 
#   $1 - keys.json 内容
#   $2 - 要检查的 key 标识符
# 返回值: 如果 key 存在则返回其值，否则返回空字符串
check_key_exists() {
    local KEYS_JSON="$1"
    local KEY="$2"
    
    # 使用 jq 检查 key 是否存在，并返回其值
    echo "$KEYS_JSON" | jq -r --arg key "$KEY" '
        if has($key) then
            .[$key]
        else
            empty
        end
    ' 2>/dev/null
}

# 验证消息类型参数
# 功能: 验证消息类型参数是否有效
# 参数: 
#   $1 - 消息类型字符串
# 返回值: 0 - 消息类型有效，1 - 消息类型无效
validate_message_type() {
    local MESSAGE_TYPE="$1"
    
    case "$MESSAGE_TYPE" in
        text|markdown|news|file|voice|image)
            return 0
            ;;
        *)
            echo "错误: 未知的消息类型: $MESSAGE_TYPE" >&2
            echo "支持的消息类型: text, markdown, news, file, voice, image" >&2
            return 1
            ;;
    esac
}

# 定义函数，根据消息类型调用 send_message.sh
# 功能: 调用底层的 send_message.sh 脚本发送消息
# 参数: 
#   $1 - Webhook key
#   $2 - 消息类型
#   $3... - 消息的具体参数
# 返回值: send_message.sh 脚本的退出码
send_message() {
    local KEY="$1"
    local MESSAGE_TYPE="$2"
    shift 2
    
    if [ -n "$KEY" ]; then
        echo "发送 $MESSAGE_TYPE 消息到 key: ${KEY:0:8}..." >&2
    else
        echo "发送 $MESSAGE_TYPE 消息到默认配置..." >&2
    fi
    
    # 简洁的参数构建方式
    local KEY_OPTION=""
    if [ -n "$KEY" ]; then
        KEY_OPTION="-k $KEY"
    fi
    
    ./send_message.sh $KEY_OPTION "$MESSAGE_TYPE" "$@"
    
    local EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
        echo "完成" >&2
    else
        echo "失败 (退出码: $EXIT_CODE)" >&2
    fi
    
    echo "" >&2
    return $EXIT_CODE
}

# 处理所有 keys 的情况
# 功能: 处理 --all 参数，向所有配置的 keys 发送消息
# 参数: 
#   $1 - keys.json 内容
#   $2 - 消息类型
#   $3... - 消息的具体参数
# 返回值: 无，所有处理结果会输出到控制台
process_all_keys() {
    local KEYS_JSON="$1"
    local MESSAGE_TYPE="$2"
    shift 2
    
    # 获取所有 key 标识符
    local KEYS
    if ! KEYS=$(echo "$KEYS_JSON" | jq -r 'keys[]' 2>/dev/null); then
        echo "错误: 无法解析 $KEYS_FILE 文件" >&2
        echo "请检查文件格式是否为有效的 JSON" >&2
        exit 1
    fi
    
    local MISSING_KEYS=()
    local VALID_KEYS=()
    local TOTAL_KEYS=0
    local PROCESSED_KEYS=0
    local SUCCESS_COUNT=0
    local FAIL_COUNT=0
    
    echo "开始处理所有配置的 keys..." >&2
    echo "" >&2
    
    for key in $KEYS; do
        TOTAL_KEYS=$((TOTAL_KEYS + 1))
        local VALUE
        if ! VALUE=$(check_key_exists "$KEYS_JSON" "$key"); then
            MISSING_KEYS+=("$key")
        elif [ -z "$VALUE" ]; then
            MISSING_KEYS+=("$key")
        else
            VALID_KEYS+=("$VALUE")
        fi
    done
    
    # 如果存在缺失的 key，输出错误信息
    if [ ${#MISSING_KEYS[@]} -ne 0 ]; then
        echo "警告: 以下标识符配置有问题: ${MISSING_KEYS[*]}" >&2
        echo "" >&2
    fi
    
    if [ ${#VALID_KEYS[@]} -eq 0 ]; then
        echo "没有找到有效的 key 配置，将使用默认配置" >&2
        echo "" >&2
        
        # 使用默认配置发送消息
        echo "[1/1] 发送到默认配置:" >&2
        if send_message "" "$MESSAGE_TYPE" "$@"; then
            SUCCESS_COUNT=1
        else
            FAIL_COUNT=1
        fi
    else
        echo "找到 ${#VALID_KEYS[@]}/$TOTAL_KEYS 个有效配置" >&2
        echo "" >&2
        
        # 发送消息到所有有效的 keys
        for key in "${VALID_KEYS[@]}"; do
            PROCESSED_KEYS=$((PROCESSED_KEYS + 1))
            echo "[$PROCESSED_KEYS/${#VALID_KEYS[@]}] " >&2
            if send_message "$key" "$MESSAGE_TYPE" "$@"; then
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            else
                FAIL_COUNT=$((FAIL_COUNT + 1))
            fi
        done
    fi
    
    echo "========================================" >&2
    echo "发送结果统计:" >&2
    echo "  成功: $SUCCESS_COUNT" >&2
    echo "  失败: $FAIL_COUNT" >&2
    if [ ${#VALID_KEYS[@]} -eq 0 ]; then
        echo "  总计: 1 (默认配置)" >&2
    else
        echo "  总计: ${#VALID_KEYS[@]}" >&2
    fi
    echo "========================================" >&2
}

# 处理指定的多个 keys 的情况
# 功能: 处理指定的多个 key 标识符，向这些 key 发送消息
# 参数: 
#   $1 - keys.json 内容
#   $2 - 要发送的 key 标识符（逗号分隔）
#   $3 - 消息类型
#   $4... - 消息的具体参数
# 返回值: 无，所有处理结果会输出到控制台
process_multiple_keys() {
    local KEYS_JSON="$1"
    local KEY_IDENTIFIER="$2"
    local MESSAGE_TYPE="$3"
    shift 3
    
    IFS=',' read -r -a KEY_ARRAY <<< "$KEY_IDENTIFIER"
    local MISSING_KEYS=()
    local VALID_KEYS=()
    local TOTAL_KEYS=${#KEY_ARRAY[@]}
    local PROCESSED_KEYS=0
    local SUCCESS_COUNT=0
    local FAIL_COUNT=0
    
    echo "开始处理指定 keys: $KEY_IDENTIFIER" >&2
    echo "" >&2
    
    for key in "${KEY_ARRAY[@]}"; do
        # 去除可能的空格
        key=$(echo "$key" | xargs)
        
        if [ -z "$key" ]; then
            continue
        fi
        
        local VALUE
        if ! VALUE=$(check_key_exists "$KEYS_JSON" "$key"); then
            MISSING_KEYS+=("$key")
        elif [ -z "$VALUE" ]; then
            MISSING_KEYS+=("$key")
        else
            VALID_KEYS+=("$VALUE")
        fi
    done
    
    # 如果存在缺失的 key，输出错误信息
    if [ ${#MISSING_KEYS[@]} -ne 0 ]; then
        echo "错误: 以下标识符不存在或配置错误: ${MISSING_KEYS[*]}" >&2
        echo "" >&2
        echo "可用的标识符:" >&2
        echo "$KEYS_JSON" | jq -r 'keys | join(", ")' >&2
        exit 1
    fi
    
    if [ ${#VALID_KEYS[@]} -eq 0 ]; then
        echo "没有找到有效的 key 配置，将使用默认配置" >&2
        echo "" >&2
        
        # 使用默认配置发送消息
        echo "[1/1] 发送到默认配置:" >&2
        if send_message "" "$MESSAGE_TYPE" "$@"; then
            SUCCESS_COUNT=1
        else
            FAIL_COUNT=1
        fi
    else
        echo "找到 ${#VALID_KEYS[@]}/$TOTAL_KEYS 个有效配置" >&2
        echo "" >&2
        
        # 发送消息到所有有效的 keys
        for key in "${VALID_KEYS[@]}"; do
            PROCESSED_KEYS=$((PROCESSED_KEYS + 1))
            echo "[$PROCESSED_KEYS/${#VALID_KEYS[@]}] " >&2
            if send_message "$key" "$MESSAGE_TYPE" "$@"; then
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            else
                FAIL_COUNT=$((FAIL_COUNT + 1))
            fi
        done
    fi
    
    echo "========================================" >&2
    echo "发送结果统计:" >&2
    echo "  成功: $SUCCESS_COUNT" >&2
    echo "  失败: $FAIL_COUNT" >&2
    if [ ${#VALID_KEYS[@]} -eq 0 ]; then
        echo "  总计: 1 (默认配置)" >&2
    else
        echo "  总计: ${#VALID_KEYS[@]}" >&2
    fi
    echo "========================================" >&2
}

# 主逻辑
# 功能: 脚本的主要执行流程
# 参数: 脚本的所有输入参数
# 返回值: 无
main() {
    # 检查依赖
    check_dependencies
    
    # 检查传入参数数量
    check_args "$@"
    
    # 获取 key 标识符和消息类型
    local KEY_IDENTIFIER="$1"
    local MESSAGE_TYPE="$2"
    shift 2
    
    # 验证消息类型
    if ! validate_message_type "$MESSAGE_TYPE"; then
        exit 1
    fi
    
    # 加载 keys.json 文件
    local KEYS_JSON
    KEYS_JSON=$(load_keys_json)
    
    # 根据 key 标识符处理不同情况
    if [ "$KEY_IDENTIFIER" = "--all" ]; then
        process_all_keys "$KEYS_JSON" "$MESSAGE_TYPE" "$@"
    else
        process_multiple_keys "$KEYS_JSON" "$KEY_IDENTIFIER" "$MESSAGE_TYPE" "$@"
    fi
}

# 脚本入口点
main "$@"
