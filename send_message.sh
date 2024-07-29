#!/bin/bash

# Shell 脚本用于发送不同类型的消息到企业微信的 Webhook 接口
# 支持发送文本消息、Markdown 格式消息、新闻格式消息、文件消息、语音消息和图片消息
#
# 使用说明：
# 1. 保存脚本为 send_message.sh
# 2. 使用命令 chmod +x send_message.sh 赋予脚本执行权限
# 3. 运行脚本，根据不同的消息类型及其参数，使用如下命令运行脚本：
#   - 发送文本消息：
#     ./send_message.sh -k "YOUR_WEBHOOK_KEY" text "大家好，我是机器人，现在在测试" "user1,user2" "13800000000,13900000000"
#   - 发送 Markdown 格式消息：
#     ./send_message.sh -k "YOUR_WEBHOOK_KEY" markdown "实时新增用户反馈<font color=\"warning\">132例</font>，请相关同事注意。\n>类型:<font color=\"comment\">用户反馈</font>\n>普通用户反馈:<font color=\"comment\">117例</font>\n>VIP 用户反馈:<font color=\"comment\">15例</font>"
#   - 发送新闻格式消息：
#     ./send_message.sh -k "YOUR_WEBHOOK_KEY" news "中秋节礼品领取, 端午节礼品领取" "今年中秋节公司有豪礼相送, 今年端午节公司有豪礼相送" "http://www.qq.com, http://www.baidu.com" "http://res.mail.qq.com/node/ww/wwopenmng/images/independent/doc/test_pic_msg1.png, http://res.mail.qq.com/node/ww/wwopenmng/images/independent/doc/test_pic_msg2.png"
#     如果没有描述或图片 URL，可以省略：
#     ./send_message.sh -k "YOUR_WEBHOOK_KEY" news "中秋节礼品领取" "" "http://www.qq.com"
#   - 发送文件消息：
#     ./send_message.sh -k "YOUR_WEBHOOK_KEY" file "/path/to/wework.txt"
#   - 发送语音消息：
#     ./send_message.sh -k "YOUR_WEBHOOK_KEY" voice "/path/to/voice.amr"
#   - 发送图片消息：
#     ./send_message.sh -k "YOUR_WEBHOOK_KEY" image "/path/to/image.jpg"
#     或者
#     ./send_message.sh -k "YOUR_WEBHOOK_KEY" image "BASE64_STRING"
#
# 作者: Ivan Zhang
# 日期: 2024/07/26

DEFAULT_KEY="[replace by your default key]"
CACHE_FILE=".media_cache"

# 读取缓存文件
read_cache() {
    if [ -f "$CACHE_FILE" ]; then
        cat "$CACHE_FILE"
    fi
}

# 写入缓存文件
write_cache() {
    local file_hash="$1"
    local media_id="$2"
    local expiry_time="$3"
    echo "$file_hash $media_id $expiry_time" >> "$CACHE_FILE"
}

# 检查文件是否已存在且未过期
check_cache() {
    local file_hash="$1"
    local current_time=$(date +%s)
    local valid_records=()
    local cached_media_id=""

    if [ -f "$CACHE_FILE" ]; then
        while read -r line; do
            cached_file_hash=$(echo "$line" | awk '{print $1}')
            cached_media_id=$(echo "$line" | awk '{print $2}')
            cached_expiry_time=$(echo "$line" | awk '{print $3}')

            if [ "$current_time" -lt "$cached_expiry_time" ]; then
                valid_records+=("$line")
                if [ "$file_hash" == "$cached_file_hash" ]; then
                    cached_media_id="$cached_media_id"
                fi
            fi
        done < "$CACHE_FILE"

        # 更新缓存文件
        printf "%s\n" "${valid_records[@]}" > "$CACHE_FILE"

        if [ -n "$cached_media_id" ]; then
            echo "$cached_media_id"
            return 0
        fi
    fi

    return 1
}

# 发送文本消息函数
send_text_message() {
    local key="$1"
    local content="$2"
    local mentioned_list="$3"
    local mentioned_mobile_list="$4"

    # 检查是否提供了消息内容
    if [ -z "$content" ]; then
        echo "Usage: send_text_message <key> <content> [mentioned_list] [mentioned_mobile_list]"
        return 1
    fi

    # 对消息内容进行 UTF-8 编码处理
    local utf8_content=$(echo -n "$content" | iconv -f utf-8 -t utf-8)

    # 构建 JSON 数据结构
    local json_data='{
        "msgtype": "text",
        "text": {
            "content": "'"$utf8_content"'"
        }
    }'

    # 如果提供了提及用户列表，则转换为 JSON 数组并添加到 JSON 数据中
    if [ -n "$mentioned_list" ]; then
        local mentioned_list_array=$(echo "$mentioned_list" | jq -R 'split(",")')
        json_data=$(echo "$json_data" | jq --argjson mentioned_list "$mentioned_list_array" '.text += {"mentioned_list": $mentioned_list}')
    fi

    # 如果提供了提及用户手机号列表，则转换为 JSON 数组并添加到 JSON 数据中
    if [ -n "$mentioned_mobile_list" ]; then
        local mentioned_mobile_list_array=$(echo "$mentioned_mobile_list" | jq -R 'split(",")')
        json_data=$(echo "$json_data" | jq --argjson mentioned_mobile_list "$mentioned_mobile_list_array" '.text += {"mentioned_mobile_list": $mentioned_mobile_list}')
    fi

    # 发送请求
    send_request "$key" "$json_data"
}

# 发送 Markdown 格式消息
# 参数:
#   $1 - 消息内容
send_markdown_message() {
    local key="$1"
    local content="$2"

    # 检查是否提供了消息内容
    if [ -z "$content" ]; then
        echo "Usage: send_markdown_message <key> <content>"
        return 1
    fi

    # 对消息内容进行 UTF-8 编码处理
    local utf8_content=$(echo -n "$content" | iconv -f utf-8 -t utf-8)

    # 构建 JSON 数据结构
    local json_data='{
        "msgtype": "markdown",
        "markdown": {
            "content": "'"$utf8_content"'"
        }
    }'

    # 发送请求
    send_request "$key" "$json_data"
}

# 发送新闻格式消息
# 参数:
#   $1 - 标题列表（逗号分隔）
#   $2 - 描述列表（逗号分隔）
#   $3 - URL 列表（逗号分隔）
#   $4 - 图片 URL 列表（逗号分隔）
send_news_message() {
    local key="$1"
    local titles="$2"
    local descriptions="$3"
    local urls="$4"
    local picurls="$5"

    # 检查是否提供了所有必要的参数
    if [ -z "$titles" ] || [ -z "$urls" ]; then
        echo "Usage: send_news_message <key> <titles> [descriptions] <urls> [picurls]"
        return 1
    fi

    # 将输入参数拆分成数组
    IFS=',' read -r -a title_array <<< "$titles"
    IFS=',' read -r -a description_array <<< "$descriptions"
    IFS=',' read -r -a url_array <<< "$urls"
    IFS=',' read -r -a picurl_array <<< "$picurls"

    # 构建 articles JSON 数据
    local articles_json='['
    for i in "${!title_array[@]}"; do
        if [ $i -ge 8 ]; then
            break
        fi

        local article_json='{
            "title": "'"${title_array[$i]}"'",
            "url": "'"${url_array[$i]}"'"
        }'

        if [ -n "${description_array[$i]}" ]; then
            article_json=$(echo "$article_json" | jq '. += {"description": "'"${description_array[$i]}"'"}')
        fi

        if [ -n "${picurl_array[$i]}" ]; then
            article_json=$(echo "$article_json" | jq '. += {"picurl": "'"${picurl_array[$i]}"'"}')
        fi

        articles_json+="$article_json"
        if [ $i -lt $((${#title_array[@]}-1)) ]; then
            articles_json+=','
        fi
    done
    articles_json+=']'

    # 构建最终的 JSON 数据结构
    local json_data='{
        "msgtype": "news",
        "news": {
        "articles": '"$articles_json"'
        }
    }'

    # 发送请求
    send_request "$key" "$json_data"
}

# 上传文件，并返回 media_id
upload_file() {
    local key="$1"
    local file_path="$2"
    local type="$3"

    # 检查是否提供了文件路径、key 和 type
    if [ -z "$file_path" ] || [ -z "$key" ] || [ -z "$type" ]; then
        echo "Usage: upload_file <key> <file_path> <type>"
        return 1
    fi

    # 检查文件是否存在
    if [ ! -f "$file_path" ]; then
        echo "错误: 文件 $file_path 不存在。"
        return 1
    fi

    # 获取文件名和文件大小
    local file_name=$(basename "$file_path")
    local file_size=$(stat -c%s "$file_path")

    # 检查文件大小是否大于 5 个字节
    if [ "$file_size" -le 5 ]; then
        echo "错误: 文件大小必须大于 5 个字节。"
        return 1
    fi

    # 检查文件类型
    case "$type" in
        file)
            if [ "$file_size" -gt $((20 * 1024 * 1024)) ]; then
                echo "错误: 普通文件大小不能超过 20MB。"
                return 1
            fi
            ;;
        voice)
            if [ "$file_size" -gt $((2 * 1024 * 1024)) ]; then
                echo "错误: 语音文件大小不能超过 2MB。"
                return 1
            fi
            # 检查文件格式是否为 AMR
            if [[ "$file_path" != *.amr ]]; then
                echo "错误: 语音文件仅支持 AMR 格式。"
                return 1
            fi
            # 检查播放长度是否超过 60s
            local duration=$(sox --i -D "$file_path")
            if (( $(echo "$duration > 60" | bc -l) )); then
                echo "错误: 语音文件播放长度不能超过 60 秒。"
                return 1
            fi
            ;;
        *)
            echo "错误: 不支持的文件类型。"
            return 1
            ;;
    esac

    # 计算文件的 SHA256 哈希值
    local file_hash=$(sha256sum "$file_path" | awk '{print $1}')

    # 检查缓存中是否已存在该文件且未过期
    local cached_media_id
    if cached_media_id=$(check_cache "$file_hash"); then
        # shell 需要使用 echo 输出返回值就是麻烦，不能有多余的 echos
        #echo "文件已存在且未过期，使用缓存的 media_id: $cached_media_id"
        echo "$cached_media_id"
        return 0
    fi

    # 上传文件
    local url="https://qyapi.weixin.qq.com/cgi-bin/webhook/upload_media?key=$key&type=$type"
    local response=$(curl -s -X POST "$url" \
        -H "Content-Type: multipart/form-data" \
        -F "media=@$file_path;filename=\"$file_name\"")

    # 解析返回的 JSON 数据
    local media_id=$(echo "$response" | jq -r '.media_id')

    # 检查请求是否成功
    if [ -z "$media_id" ] || [ "$media_id" == "null" ]; then
        echo "文件上传失败: $response"
        return 1
    else
        # 计算文件的过期时间（3 天后）
        local expiry_time=$(($(date +%s) + 3 * 24 * 60 * 60))
        # 写入缓存
        write_cache "$file_hash" "$media_id" "$expiry_time"
        echo "$media_id" # 返回 media_id
    fi
}

# 发送文件消息
# 参数:
#   $1 - 群接口 key
#   $2 - 文件路径
send_file_message() {
    local key="$1"
    local file_path="$2"

    # 检查是否提供了文件路径和 key
    if [ -z "$file_path" ] || [ -z "$key" ]; then
        echo "Usage: send_file_message <key> <file_path>"
        return 1
    fi

    # 上传文件并获取 media_id
    local media_id=$(upload_file "$key" "$file_path" "file")
    if [ $? -ne 0 ]; then
        return 1
    fi

    # 构建 JSON 数据结构
    local json_data='{
        "msgtype": "file",
        "file": {
            "media_id": "'"$media_id"'"
        }
    }'

    # 发送请求
    send_request "$key" "$json_data"
}

# 发送语音消息
# 参数:
#   $1 - 群接口 key
#   $2 - 语音文件路径
send_voice_message() {
    local key="$1"
    local file_path="$2"

    # 检查是否提供了语音文件路径和 key
    if [ -z "$file_path" ] || [ -z "$key" ]; then
        echo "Usage: send_voice_message <key> <file_path>"
        return 1
    fi

    # 上传语音文件并获取 media_id
    local media_id=$(upload_file "$key" "$file_path" "voice")
    if [ $? -ne 0 ]; then
        return 1
    fi

    # 构建 JSON 数据结构
    local json_data='{
        "msgtype": "voice",
        "voice": {
            "media_id": "'"$media_id"'"
        }
    }'

    # 发送请求
    send_request "$key" "$json_data"
}

# 发送图片消息
# 参数:
#   $1 - 群接口 key
#   $2 - 图片路径或 Base64 字符串
send_image_message() {
    local key="$1"
    local image_path_or_base64="$2"

    # 检查是否提供了图片路径或 Base64 字符串
    if [ -z "$image_path_or_base64" ] || [ -z "$key" ]; then
        echo "Usage: send_image_message <key> <image_path_or_base64>"
        return 1
    fi

    if [ -f "$image_path_or_base64" ]; then
        # 检查文件格式是否为 jpg 或 png
        local file_extension="${image_path_or_base64##*.}"
        if [[ ! "$file_extension" =~ ^(jpg|png|jpeg)$ ]]; then
            echo "错误: 仅支持 jpg, jpeg 和 png 格式的图片。"
            return 1
        fi

        # 检查文件大小是否超过 2MB
        local file_size=$(stat -c%s "$image_path_or_base64")
        if [ "$file_size" -gt $((2 * 1024 * 1024)) ]; then
            echo "错误: 文件大小不能超过 2MB。"
            return 1
        fi

        # 读取文件内容并进行 Base64 编码
        local base64_data=$(base64 -w 0 "$image_path_or_base64")
        # 计算文件内容的 MD5 值
        local md5_value=$(md5sum "$image_path_or_base64" | awk '{print $1}')
    else
        # 直接使用传入的 Base64 字符串
        local base64_data="$image_path_or_base64"
        # 计算 Base64 字符串解码后的 MD5 值
        local decoded_data=$(echo "$base64_data" | base64 -d)
        local md5_value=$(echo -n "$decoded_data" | md5sum | awk '{print $1}')
    fi

    # 构建 JSON 数据结构
    local json_data='{
        "msgtype": "image",
        "image": {
            "base64": "'"$base64_data"'",
            "md5": "'"$md5_value"'"
        }
    }'

    # 发送请求
    send_request "$key" "$json_data"
}

# 发送 HTTP 请求函数
# 参数:
#   $1 - 群接口 key
#   $2 - JSON 数据
send_request() {
    local key="$1"
    local json_data="$2"
    local url="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=${key}"

    local response=$(curl -s -X POST "$url" \
        -H 'Content-Type: application/json' \
        -d "$json_data")

    # 检查请求是否成功
    local errcode=$(echo "$response" | jq -r '.errcode')
    if [ "$errcode" == "0" ]; then
        echo "消息发送成功: $response"
    else
        echo "消息发送失败: $response"
    fi
}

# 主函数，根据传递的参数调用不同的函数
# 参数:
#   -k key - 群接口 key
#   $1 - 消息类型 (text, markdown, news, file, voice, image)
#   $@ - 剩余的参数根据消息类型的不同而不同
main() {
    local key="$DEFAULT_KEY"
    local msgtype

    while getopts "k:" opt; do
        case $opt in
            k)
                key="$OPTARG"
                ;;
            *)
                echo "Usage: $0 [-k key] {text|markdown|news|file|voice|image} [arguments...]"
                return 1
                ;;
        esac
    done
    shift $((OPTIND - 1))

    msgtype="$1"
    shift

    case "$msgtype" in
        text)
            send_text_message "$key" "$@"
            ;;
        markdown)
            send_markdown_message "$key" "$@"
            ;;
        news)
            send_news_message "$key" "$@"
            ;;
        file)
            send_file_message "$key" "$@"
            ;;
        voice)
            send_voice_message "$key" "$@"
            ;;
        image)
            send_image_message "$key" "$@"
            ;;
        *)
            echo "Usage: $0 [-k key] {text|markdown|news|file|voice|image} [arguments...]"
            return 1
            ;;
    esac
}

# 调用主函数
main "$@"
