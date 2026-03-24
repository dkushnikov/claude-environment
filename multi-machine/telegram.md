# Telegram Bot Integration

Run Claude Code as a Telegram bot on your server. Message from your phone, get full vault access.

## How it works

```
Phone (Telegram) → Bot → Claude Code session (server, tmux) → Vault
                                    ↓
                          Obsidian Sync → all devices see changes
```

The bot is a persistent Claude Code session with the `telegram` channel plugin. It has full capabilities: read/write files, run tools, use MCP servers. Changes sync to all devices via Obsidian Sync.

## Setup

### Prerequisites
- Server with Claude Code installed
- [Bun](https://bun.sh) runtime: `curl -fsSL https://bun.sh/install | bash`
- Obsidian running on server (for Sync + CLI)

### 1. Create bot via @BotFather
Open Telegram, message [@BotFather](https://t.me/BotFather), send `/newbot`. Choose a name and username (must end in `bot`). Save the token.

### 2. Install plugin
```bash
claude
/plugin install telegram@claude-plugins-official
```

### 3. Configure token
```bash
/telegram:configure <your-token>
```
Writes to `~/.claude/channels/telegram/.env`. You can also write this file manually.

### 4. Launch with channels
```bash
# Exit current session, then:
claude --channels plugin:telegram@claude-plugins-official
```

### 5. Pair
- DM your bot on Telegram — it replies with a 6-char pairing code
- In the Claude session: `/telegram:access pair <code>`
- Lock down: `/telegram:access policy allowlist`

### 6. Make it persistent

**tmux (simple):**
```bash
tmux new-session -d -s telegram \
  'cd ~/Obsidian/YourVault && claude --channels plugin:telegram@claude-plugins-official'
```

**LaunchAgent (macOS, auto-start):**
Create a LaunchAgent that starts the tmux session at login.

## What the bot can do

| Tool | Purpose |
|------|---------|
| `reply` | Send text + files to a chat |
| `react` | Add emoji reaction to a message |
| `edit_message` | Update a previously sent message (progress indicators) |

Plus all standard Claude Code tools: file read/write, Bash, MCP servers, skills.

## Limitations

- **No message history** — bot only sees incoming messages, can't search or fetch old ones
- **Photos compressed** — send as File (long-press → Send as File) for originals
- **Response time** — depends on server hardware and model. First message after idle is slower
- **Permissions** — server `settings.local.json` may prompt for tool approval. Pre-configure common operations to reduce friction

## Tips

- **Obsidian Sync is essential.** Without it, the bot writes to a stale vault and changes don't reach your other devices
- **Pre-allow common tools** in the server's `settings.local.json` to avoid permission prompts for every message
- **One bot per vault.** If you have multiple vaults (personal, work), consider separate bots or a routing mechanism
- **DMs only by default.** See the plugin's ACCESS.md for group chat configuration

## Use cases

- Quick capture from phone: "запиши в daily note: встретился с X, обсудили Y"
- Vault queries: "что у меня в TODO?"
- Running skills: "/plaud-status", "/calendar-status"
- Remote reflection: triggering daily reflection from the couch
