# NEO

A personalized AI infrastructure for building custom agents, skills, commands, and automations tailored to individual needs. This is my own AI operating system—feel free to clone it as a starting point for building yours.

> **Built for Claude** — NEO is designed specifically for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). If you're using another model, you can still use the agents, skills, and commands—they're just markdown prompts after all—but you'll need to make manual adjustments to fit your model's conventions and tooling.

## Inspiration

This project draws inspiration from:

- [danielmiessler/Personal_AI_Infrastructure](https://github.com/danielmiessler/Personal_AI_Infrastructure) — A comprehensive template for building your own AI-powered operating system
- [ComposioHQ/awesome-claude-skills](https://github.com/ComposioHQ/awesome-claude-skills) — Curated collection of customizable Claude workflows
- [travisvn/awesome-claude-skills](https://github.com/travisvn/awesome-claude-skills) — Guide to Claude Skills with efficiency-focused design patterns

## Philosophy

- **Personal-first**: Built for my specific workflows, not generic use cases
- **Modular**: Each skill, agent, and automation is self-contained and composable
- **Extensible**: Easy to add new capabilities without modifying existing ones
- **CLI-native**: Designed to work seamlessly with Claude Code and terminal workflows

## Structure

```
.
├── agents/              # Custom subagents (Markdown + YAML frontmatter)
├── commands/            # Custom slash commands
├── skills/              # Domain-specific capabilities
├── hooks/               # Hook scripts for observability & control
├── settings.json        # Claude Code configuration (includes hooks)
├── .mcp.json            # MCP server configuration
└── setup.sh             # Symlink installer
```

After running `setup.sh`, your `~/.claude/` will have symlinks pointing to this repo:

```
~/.claude/
├── agents/          → ~/path/to/neo/agents/
├── commands/        → ~/path/to/neo/commands/
├── skills/          → ~/path/to/neo/skills/
├── settings.json    → ~/path/to/neo/settings.json
├── .mcp.json        → ~/path/to/neo/.mcp.json
├── projects/        # Claude's internal (untouched)
├── todos/           # Claude's internal (untouched)
└── ...              # Other Claude runtime data
```

## Getting Started

1. **Clone this repository**
   ```bash
   git clone https://github.com/tolgaio/neo.git
   cd neo
   ```

2. **Run the setup script**
   ```bash
   ./setup.sh
   ```
   This creates symlinks from `~/.claude/` to this repo. Existing files are backed up.

3. **Customize for your needs**
   - Add agents to `agents/`
   - Create commands in `commands/`
   - Add skills to `skills/`
   - Configure MCP servers in `.mcp.json`
   - Define hooks in `settings.json`

## Skills

Skills are self-contained AI capabilities that teach Claude how to perform specific tasks. Each skill includes:

```
skills/
└── example-skill/
    ├── SKILL.md         # Instructions and metadata
    ├── scripts/         # Helper utilities (optional)
    ├── templates/       # Output templates (optional)
    └── resources/       # Reference materials (optional)
```

### Skill Template

```markdown
# Skill Name

## Description
Brief description of what this skill does.

## Triggers
- Keywords or contexts that activate this skill

## Instructions
Step-by-step instructions for Claude to follow.

## Examples
Input/output examples demonstrating the skill.
```

## Commands

Custom slash commands for quick access to common operations:

```
commands/
├── review.md            # Code review workflow
├── refactor.md          # Refactoring assistant
└── document.md          # Documentation generator
```

## Agents

[Custom subagents](https://code.claude.com/docs/en/sub-agents) are pre-configured AI personalities with specific expertise. Each agent is a Markdown file with YAML frontmatter:

```markdown
---
name: researcher
description: Deep-dive research and analysis of complex topics
tools: Read, Grep, Glob, WebFetch, WebSearch
model: opus
---

You are a thorough researcher. When given a topic:
1. Search for authoritative sources
2. Cross-reference information
3. Synthesize findings into clear summaries
4. Cite sources for all claims
```

### Managing Agents

```bash
/agents              # Interactive menu to view/create/edit agents
```

Claude automatically invokes matching agents based on task context, or you can explicitly request one.

## MCP (Model Context Protocol)

[MCP](https://modelcontextprotocol.io/) is an open standard that connects AI applications to external data sources and tools—like a USB-C port for AI. Configure MCP servers in `.mcp.json`:

```json
{
  "mcpServers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/"
    },
    "postgres": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@bytebase/dbhub"],
      "env": {
        "DB_CONNECTION": "${DATABASE_URL}"
      }
    },
    "notion": {
      "type": "http",
      "url": "https://mcp.notion.com/mcp",
      "headers": {
        "Authorization": "Bearer ${NOTION_API_KEY}"
      }
    }
  }
}
```

### Server Types

| Type | Description |
|------|-------------|
| `http` | Remote server via HTTP (recommended) |
| `stdio` | Local process on your machine |
| `sse` | Server-Sent Events (deprecated) |

### Managing MCP Servers

```bash
claude mcp add <name> <url>        # Add a server
claude mcp list                    # List configured servers
claude mcp remove <name>           # Remove a server
/mcp                               # Check server status in Claude Code
```

## Hooks

[Claude Code hooks](https://code.claude.com/docs/en/hooks) are automated triggers that execute scripts at specific events during Claude sessions. They enable observability, validation, and control of AI agent behavior.

### Hook Types

| Hook | When it Fires | Use Case |
|------|---------------|----------|
| `PreToolUse` | Before a tool executes | Validate/block operations |
| `PostToolUse` | After a tool completes | Log changes, run formatters |
| `Notification` | On permission prompts | Custom alerts |
| `UserPromptSubmit` | When user submits prompt | Input validation |
| `Stop` | Main agent finishes | Summary logging |
| `SubagentStop` | Subagent (Task) finishes | Track agent activity |
| `SessionStart` | Session begins | Inject context |
| `SessionEnd` | Session ends | Cleanup tasks |

### Configuration

Hooks are configured in `settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "hooks/log-file-change.sh \"$CLAUDE_FILE_PATH\"",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

### Observability Use Cases

- **Activity logging** — Track all tool invocations and file changes
- **Metrics collection** — Send events to monitoring systems (DataDog, Grafana)
- **Cost tracking** — Monitor API usage and token consumption
- **Audit trails** — Record what the AI modified and when
- **Notifications** — Slack/Discord alerts on specific events

```
hooks/
├── log-activity.sh      # Log tool usage to file/service
├── notify-slack.sh      # Send Slack notifications
└── track-metrics.sh     # Push metrics to monitoring
```

## Contributing

This is a personal system, but feel free to:

- Fork and adapt for your own use
- Open issues for questions or suggestions
- Submit PRs if you build something useful

## License

MIT — Use freely, attribution appreciated.

---

*Building AI systems that work the way you think.*
