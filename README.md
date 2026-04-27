# ccx — Claude Code 配置切换器（CLI）

一个**单文件 Python 脚本**，零依赖，用来在多个 Claude Code 后端（AnyRouter / PackyCode / 官方 / 第三方中转 等）之间切换。

写这个工具是因为 [`cc-switch`](https://github.com/farion1231/cc-switch) 是 Tauri 桌面应用，对纯命令行环境（SSH / WSL / 服务器）不太友好。`ccx` 干同样的事，但是只用 CLI、只切 Claude Code 一个工具、不带界面、不带数据库。

---

## 它做什么

切换 provider 时，`ccx` **只重写** `~/.claude/settings.json` 里的 `env` 块（且只改 `ANTHROPIC_*` 这些它自己管的 key），其它 `permissions` / `hooks` / `enabledPlugins` 等配置原样保留。

```
~/.claude/settings.json   ← Claude Code 实际读取的配置（live）
~/.config/ccx/config.json ← ccx 自己存的所有 provider
~/.config/ccx/backups/    ← 每次切换前自动备份 settings.json（保留最近 20 份）
```

---

## 安装

需要 Python ≥ 3.9（Ubuntu 20.04+ 自带）。

**一行安装：**

```bash
mkdir -p ~/.local/bin && \
curl -fsSL https://raw.githubusercontent.com/Harrisonford-ss/ccx/main/ccx -o ~/.local/bin/ccx && \
chmod +x ~/.local/bin/ccx
```

或者跑安装脚本：

```bash
curl -fsSL https://raw.githubusercontent.com/Harrisonford-ss/ccx/main/install.sh | bash
```

确认 `~/.local/bin` 在 `$PATH` 里：

```bash
echo $PATH | tr ':' '\n' | grep -q "$HOME/.local/bin" || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

验证：

```bash
ccx --help
```

---

## 用法

### 添加 provider

交互式（会隐式输入 token）：

```bash
ccx add anyrouter
# ANTHROPIC_BASE_URL: https://api.anyrouter.top
# ANTHROPIC_AUTH_TOKEN (input hidden): ****
```

一行命令：

```bash
ccx add packy \
  --url https://api.packycode.com \
  --token sk-xxxxxxxxxxxxxxxx \
  --model claude-sonnet-4-5 \
  --use                 # 添加完立刻切过去
```

更细粒度（指定不同 tier 的模型 / 任意额外 env）：

```bash
ccx add my-relay \
  --url https://relay.example.com/v1 \
  --token sk-xxx \
  --haiku  claude-haiku-4-5 \
  --sonnet claude-sonnet-4-6 \
  --opus   claude-opus-4-7 \
  --env CLAUDE_CODE_API_KEY_HELPER_TTL_MS=3600000
```

如果你的中转用 `ANTHROPIC_API_KEY` 而不是 `ANTHROPIC_AUTH_TOKEN`：

```bash
ccx add foo --url https://... --token sk-xxx --api-key-field ANTHROPIC_API_KEY
```

### 切换 / 查询

```bash
ccx list                # 列出所有 provider，* 标记当前
ccx use anyrouter       # 切换到 anyrouter
ccx current             # 看当前是谁，以及它的 env（token 默认打码）
ccx show anyrouter            # 查看完整 JSON（token 打码）
ccx show anyrouter --reveal   # 显示完整 token
```

### 修改 / 删除

```bash
ccx edit anyrouter      # 用 $EDITOR 打开 JSON 改，保存后自动生效
ccx rm anyrouter        # 删除（如果删的是当前 provider，会同步清空 live env）
```

### 从 cc-switch 迁移

如果你之前用过 [cc-switch](https://github.com/farion1231/cc-switch) 桌面版：

```bash
ccx import-cc-switch
```

它会读 `~/.cc-switch/cc-switch.db`，把里面所有 `app_type='claude'` 的 provider 搬到 ccx。**不会**自动激活——迁完以后用 `ccx use <name>` 切换。

---

## 命令一览

| 命令 | 作用 |
|---|---|
| `ccx list` (`ls`) | 列出所有 provider |
| `ccx add <name> ...` | 添加 provider |
| `ccx use <name>` | 切换到指定 provider |
| `ccx current` | 显示当前 provider |
| `ccx show <name>` | 查看 provider 详情 |
| `ccx edit <name>` | 用编辑器修改 provider |
| `ccx rm <name>` | 删除 provider |
| `ccx import-cc-switch` | 从 cc-switch SQLite DB 导入 |

每个子命令都支持 `-h` 看帮助，比如 `ccx add -h`。

---

## 工作原理

1. **存储**：所有 provider 存在 `~/.config/ccx/config.json`，结构：

   ```json
   {
     "current": "anyrouter",
     "providers": {
       "anyrouter": {
         "name": "AnyRouter",
         "env": {
           "ANTHROPIC_BASE_URL": "https://api.anyrouter.top",
           "ANTHROPIC_AUTH_TOKEN": "sk-xxx",
           "ANTHROPIC_MODEL": "claude-sonnet-4-5"
         }
       }
     }
   }
   ```

2. **切换**：
   - 备份当前 `~/.claude/settings.json` 到 `~/.config/ccx/backups/settings.json.YYYYMMDD-HHMMSS`
   - 读取现有 settings.json，**只删掉** `env` 里 ccx 管的 key（`ANTHROPIC_*` 和少量 `CLAUDE_CODE_*`），**保留**所有其它 env
   - 把目标 provider 的 env 合并进去
   - **原子写**（先写 `.tmp`，`fsync`，再 `rename`），半路掉电也不会写坏

3. **不碰**的内容：
   - `~/.claude/settings.json` 里 `permissions` / `hooks` / `enabledPlugins` / `extraKnownMarketplaces` / `theme` / 等所有非 `env` 字段
   - `env` 里非 `ANTHROPIC_*` 也非 `CLAUDE_CODE_*` 的自定义 key
   - `~/.claude.json`（MCP / 项目级配置）
   - `~/.claude/` 下其它任何文件

---

## 卸载

```bash
rm ~/.local/bin/ccx
rm -rf ~/.config/ccx
```

不会动 `~/.claude/`。如果想恢复某次切换前的 settings.json，从 `~/.config/ccx/backups/` 里捞最近一份，或者删除前先：

```bash
cp ~/.config/ccx/backups/settings.json.<timestamp> ~/.claude/settings.json
```

---

## FAQ

**Q: 跟 `cc-switch` 比少了什么？**

A: 没有 GUI、没有 50+ 内置预设、没有 MCP / Skills / 用量统计 / 代理接管。只切 Claude Code 的 provider，仅此而已。

**Q: 改 settings.json 会被 Claude Code 自动 reload 吗？**

A: 已经在跑的 `claude` 会话不会自动 reload env，需要重启会话。新启动的会话会读到新 env。

**Q: 我不用 token，用账号登录的 Claude Code，能用 ccx 吗？**

A: 能，但 ccx 的存在本来就是为了切换 token-based 的第三方 provider。如果你只用官方账号登录，没必要装。

**Q: token 怎么存的？**

A: 明文存在 `~/.config/ccx/config.json` 和 `~/.claude/settings.json`，跟 `cc-switch` 一样。文件权限默认 `600` / `644`，请保证机器本身安全。

---

## License

MIT
