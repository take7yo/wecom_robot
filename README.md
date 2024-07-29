## 企业微信机器人

根据企业微信官网机器人 api 封装的 bash 实现。

此脚本现在支持发送文本消息、Markdown 格式消息、新闻格式消息、文件消息、语音消息和图片消息。

每种消息类型都封装在单独的函数中，并对内容进行了 UTF-8 编码处理。

脚本根据传入的参数生成相应的 JSON 数据结构，并通过 curl 发送 HTTP 请求。

实现中添加了文件和语音内容的缓存机制，避免重复上传相同文件，并对媒体内容进行格式和大小检查，同时包含文件的过期检查以确保使用最新的媒体文件。

### 示例调用信息：
- 发送文本消息：
  ```shell
  ./send_message.sh -k "YOUR_WEBHOOK_KEY" text "大家好，我是机器人，现在在测试" "user1,user2" "13800000000,13900000000"
  ```

- 发送 Markdown 格式消息：
  ```shell
  ./send_message.sh -k "YOUR_WEBHOOK_KEY" markdown "实时新增用户反馈<font color=\"warning\">132例</font>，请相关同事注意。\n>类型:<font color=\"comment\">用户反馈</font>\n>普通用户反馈:<font color=\"comment\">117例</font>\n>VIP 用户反馈:<font color=\"comment\">15例</font>"
  ```

- 发送新闻格式消息：
  ```shell
  ./send_message.sh -k "YOUR_WEBHOOK_KEY" news "中秋节礼品领取, 端午节礼品领取" "今年中秋节公司有豪礼相送, 今年端午节公司有豪礼相送" "http://www.qq.com, http://www.baidu.com" "http://res.mail.qq.com/node/ww/wwopenmng/images/independent/doc/test_pic_msg1.png, http://res.mail.qq.com/node/ww/wwopenmng/images/independent/doc/test_pic_msg2.png"
  ```
  如果没有描述或图片 URL，可以省略：
  ```shell
  ./send_message.sh -k "YOUR_WEBHOOK_KEY" news "中秋节礼品领取" "" "http://www.qq.com"
  ```

- 发送文件消息：
  ```shell
  ./send_message.sh -k "YOUR_WEBHOOK_KEY" file "/path/to/wework.txt"
  ```

- 发送语音消息：
  ```shell
  ./send_message.sh -k "YOUR_WEBHOOK_KEY" voice "/path/to/voice.amr"
  ```

- 发送图片消息：
  ```shell
  ./send_message.sh -k "YOUR_WEBHOOK_KEY" image "/path/to/image.jpg"
  ```
  或者
  ```shell
  ./send_message.sh -k "YOUR_WEBHOOK_KEY" image "BASE64_STRING"
  ```
请将 `YOUR_WEBHOOK_KEY` 替换为企业微信 Webhook 接口的实际 key，`/path/to/` 替换为实际的文件路径或 Base64 字符串内容。
如果你有常用的机器人，`-k "YOUR_WEBHOOK_KEY"` 可以通过修改脚本的默认 key 省略掉。

### 多机器人处理

现在我们有很多的机器人，即有很多的 key，直接传入有点麻烦，让我们再写一个脚本，用 json 定义各个 `YOUR_WEBHOOK_KEY` 信息，维护在脚本里，然后用 `./wecom_robot.sh [json 定义的 key]` 替换 `./send_message.sh -k "YOUR_WEBHOOK_KEY"` 部分调用。

同时，在指定的 `key` 不存在时，不传递 `-k` 参数给 `send_message.sh`，从而使用 `send_message.sh` 中默认定义的 `YOUR_WEBHOOK_KEY`。

**使用步骤如下：**

1. 确保 `keys.json` 文件存在并包含相应的 `YOUR_WEBHOOK_KEY` 信息（如果没有文件，脚本会处理为空对象）。例如：
   ```json
   {
     "key1": "YOUR_WEBHOOK_KEY_ONE",
     "key2": "YOUR_WEBHOOK_KEY_TWO",
     "key3": "YOUR_WEBHOOK_KEY_THREE"
   }
   ```

2. 使 `wecom_robot.sh` 可执行：

   ```shell
   chmod +x wecom_robot.sh
   ```

3. 使用 `wecom_robot.sh` 来发送消息。

   - **发送给所有 key：**
   ```shell
   ./wecom_robot.sh --all text "大家好，我是机器人，现在在测试" "user1,user2" "13800000000,13900000000"
   ```

   - **使用单个 key：**
   ```shell
   ./wecom_robot.sh key1 text "大家好，我是机器人，现在在测试" "user1,user2" "13800000000,13900000000"
   ```

   - **如果 `keys.json` 文件不存在或指定的 key 不存在，则会自动使用 `send_message.sh` 中的默认 `YOUR_WEBHOOK_KEY`：**
   ```shell
   ./wecom_robot.sh nonexistent_key text "大家好，我是机器人，现在在测试" "user1,user2" "13800000000,13900000000"
   ```
   这样，当指定的 key 不存在时，脚本会输出中文提示信息，并使用默认的 `YOUR_WEBHOOK_KEY`。
