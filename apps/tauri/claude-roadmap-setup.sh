#!/bin/bash
# Claude Roadmap Commands Installer
# Run with: curl -sSL https://your-repo/install.sh | bash

set -e

echo "🚀 Installing Claude Roadmap Commands..."

# Ensure Claude directory exists
mkdir -p ~/.claude/commands

# Download and install commands (you'd host these files)
echo "📥 Installing roadmap commands..."

# For now, create the commands directly (in real distribution, you'd download)
cat > ~/.claude/commands/roadmap.md << 'EOF'
# Roadmap Management

A project-specific command for managing the ROADMAP.md file.

## Usage

Use `/project:roadmap` followed by actions to interact with the project roadmap.

## Available Actions

### Show roadmap sections
- `/project:roadmap show` - Display entire roadmap
- `/project:roadmap show completed` - Show completed features only
- `/project:roadmap show planned` - Show planned features
- `/project:roadmap show high-priority` - Show high priority items

### Add new items
- `/project:roadmap add "Feature Name"` - Add new feature to planned section
- `/project:roadmap add "Feature Name" --priority high` - Add with priority

### Update status
- `/project:roadmap complete "Feature Name"` - Mark feature as completed
- `/project:roadmap start "Feature Name"` - Move to in-progress

### Analytics
- `/project:roadmap analyze` - Show roadmap analytics and progress
- `/project:roadmap timeline` - Estimate timeline for remaining work

When you use these commands, I will read and parse the ROADMAP.md file, perform the requested action, update the file if needed, and provide formatted output with progress and next steps.
EOF

cat > ~/.claude/commands/progress.md << 'EOF'
# Progress Tracking

Quick commands for tracking development progress.

## Usage

`/project:progress` - Show overall project progress from roadmap

## What it does

Analyzes the ROADMAP.md file and provides:
- Completion percentage
- Features completed this sprint/release
- High priority items remaining
- Estimated timeline for next milestones

Perfect for standups, sprint reviews, or stakeholder updates.
EOF

cat > ~/.claude/commands/next.md << 'EOF'
# Next Task Recommendation

Get intelligent recommendations for what to work on next.

## Usage

`/project:next` - Recommend next feature/task based on roadmap priorities and dependencies

## What it does

Analyzes the roadmap and suggests the best next item to work on based on:
- Priority level (high priority features first)
- Dependencies (items with completed dependencies)
- Effort vs impact ratio
- Current sprint capacity
- Your recent completion patterns

This helps prioritize work and maintain momentum by suggesting the most logical next step.
EOF

cat > ~/.claude/commands/user-roadmap.md << 'EOF'
# Personal Roadmap Management

Manage your personal cross-project roadmap using `/user:roadmap`.

Uses `~/.claude/personal-roadmap.md` as your personal roadmap file.

## Available Actions

- `/user:roadmap show` - Display entire personal roadmap
- `/user:roadmap show active` - Show currently active work  
- `/user:roadmap show backlog` - Show backlog items
- `/user:roadmap add "Project: Feature"` - Add to backlog
- `/user:roadmap start "Item"` - Move to active work
- `/user:roadmap complete "Item"` - Mark as done
EOF

# Create personal roadmap template if it doesn't exist
if [ ! -f ~/.claude/personal-roadmap.md ]; then
    echo "📋 Creating personal roadmap template..."
    cat > ~/.claude/personal-roadmap.md << 'EOF'
# Personal Project Roadmap

*Cross-project planning and priority management*

## 🚧 Active Work (Current Sprint)

### High Priority
- [ ] **Project: Feature** - Description

### Learning/Research
- [ ] **Learning: Topic** - Research and skill development

## 📋 Backlog (Prioritized)

### Next Up (High Impact)
- [ ] **Project: Feature** - High impact item

### Medium Priority  
- [ ] **Project: Feature** - Medium priority work

### Exploration
- [ ] **New Ideas: Concept** - Research and prototyping

## ⏸️ Paused

*Items waiting for external dependencies, feedback, or deprioritized*

## ✅ Recently Completed

- [x] **Project: Feature** - Recently completed work

## 📊 Project Health

### Active Projects
- **Project Name**: Status and health

### Capacity Management
- **Current Load**: X active items
- **Focus**: Primary focus area
- **Next Context**: Planned next focus

---

*Last Updated: $(date +'%Y-%m-%d')*
*Managed via `/user:roadmap` commands*
EOF
    echo "✅ Created personal roadmap at ~/.claude/personal-roadmap.md"
else
    echo "ℹ️  Personal roadmap already exists, skipping template creation"
fi

echo ""
echo "🎉 Claude Roadmap Commands installed successfully!"
echo ""
echo "Available commands:"
echo "  📁 Project Level:"
echo "    /project:roadmap [show|add|complete|analyze]"
echo "    /project:progress"
echo "    /project:next"
echo ""
echo "  👤 Personal Level:"
echo "    /user:roadmap [show|add|start|complete]"
echo ""
echo "💡 Try: /project:roadmap show planned"
echo "💡 Try: /user:roadmap show active"