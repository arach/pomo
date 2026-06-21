# Claude Roadmap Commands Distribution

## Quick Setup

```bash
# Create the package
cd ~/.claude
tar -czf claude-roadmap-commands.tar.gz commands/roadmap.md commands/progress.md commands/next.md commands/user-roadmap.md personal-roadmap.md

# Install on new machine
cd ~/.claude
tar -xzf claude-roadmap-commands.tar.gz
```

## Git Repository Structure

```
claude-roadmap-commands/
├── README.md
├── install.sh
├── commands/
│   ├── roadmap.md
│   ├── progress.md  
│   ├── next.md
│   └── user-roadmap.md
└── templates/
    └── personal-roadmap.md
```

## Install Script

```bash
#!/bin/bash
# install.sh

# Ensure Claude commands directory exists
mkdir -p ~/.claude/commands

# Install commands
cp commands/*.md ~/.claude/commands/

# Setup personal roadmap if it doesn't exist
if [ ! -f ~/.claude/personal-roadmap.md ]; then
    cp templates/personal-roadmap.md ~/.claude/personal-roadmap.md
    echo "✅ Created personal roadmap at ~/.claude/personal-roadmap.md"
fi

echo "✅ Claude roadmap commands installed!"
echo "Available commands:"
echo "  /project:roadmap, /project:progress, /project:next"  
echo "  /user:roadmap"
```