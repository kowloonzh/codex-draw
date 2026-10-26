# codex-draw

一个 Claude Code Skill：调用本机 [Codex CLI](https://github.com/openai/codex) 内置的图像生成能力来文生图或基于参考图改图。走 ChatGPT 订阅额度，无需 API key。

## 安装

```bash
git clone git@github.com:kowloonzh/codex-draw.git ~/.claude/skills/codex-draw
```

前置条件：已安装 `codex` 命令，并用 `codex login` 以 ChatGPT 账号登录。

## 使用

在 Claude Code 中：

```
/codex-draw <画面描述> [输出路径] [参考图...]
```

也可以直接调用脚本：

```bash
./draw.sh -p "<提示词>" -o out.png [-i 参考图1 -i 参考图2 ...]
```

| 参数 | 说明 |
| --- | --- |
| `-p` | 提示词（必填） |
| `-o` | 输出 PNG 路径，默认 `./codex-draw-<时间戳>.png` |
| `-i` | 参考图，可多次传入；传入后为改图模式 |

成功时脚本最后一行输出 `SAVED: <绝对路径>`。单张约需 1 分钟。
