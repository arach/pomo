# Roadmap Command Examples

## Real-world usage scenarios for the `/roadmap` command in Claude Code

### 📊 Daily Standup Check
```bash
# Quick overview of current work
/roadmap show in-progress

# See what's coming up next
/roadmap show high-priority
```

### 🎯 Sprint Planning Session
```bash
# Analyze project health
/roadmap analyze

# Get timeline estimates
/roadmap analyze timeline

# See effort distribution
/roadmap analyze effort
```

### ✨ Feature Brainstorming
```bash
# Add new ideas quickly
/roadmap add feature "AI-Powered Break Suggestions" --priority low --effort high --impact medium

# Organize into sections
/roadmap add feature "Voice Commands" --section "Future Ideas" --priority medium
```

### 🎉 Celebrating Wins
```bash
# Mark major milestones complete
/roadmap complete "Web Version Support"

# See overall progress
/roadmap show completed

# Export achievements for team updates
/roadmap export --section "Completed Features"
```

### 🔄 Roadmap Maintenance
```bash
# Reprioritize based on user feedback
/roadmap update "Custom Theme Creator" --priority high

# Move items between sections
/roadmap update "Mobile App" --move-to "Future Ideas"

# Update effort estimates after research
/roadmap update "Focus Mode Extension" --effort medium
```

### 📈 Stakeholder Updates
```bash
# Generate executive summary
/roadmap analyze

# Export for presentations
/roadmap export --format json

# Show recent accomplishments
/roadmap show completed --recent
```

### 🏗️ Architecture Planning
```bash
# Check dependencies before starting work
/roadmap analyze dependencies

# See what's blocked vs ready
/roadmap show --filter ready

# Plan technical debt work
/roadmap show --section "Technical Debt"
```

## Power User Workflows

### Morning Routine
```bash
# Check overnight changes
/roadmap show --updated today

# Plan daily priorities  
/roadmap show high-priority --limit 3

# Update current work status
/roadmap update "Statistics Dashboard" --status in-progress
```

### End of Sprint
```bash
# Celebrate completions
/roadmap complete "Session Naming"
/roadmap complete "Menu Bar Integration"

# Plan next sprint
/roadmap analyze timeline --next-sprint

# Update roadmap file
git add ROADMAP.md && git commit -m "📝 Update roadmap after sprint completion"
```

### Product Demo Prep
```bash
# Get compelling metrics
/roadmap analyze

# Export clean presentation data
/roadmap export --format json --completed-only

# Highlight upcoming features
/roadmap show high-priority --presentation-mode
```

## Integration Scenarios

### With Git Workflow
```bash
# After completing a feature branch
git checkout master
git merge feature/statistics-dashboard
/roadmap complete "Session Statistics Dashboard"
git add ROADMAP.md && git commit -m "✅ Complete statistics dashboard feature"
```

### With Issue Tracking
```bash
# Link roadmap to GitHub issues
/roadmap update "Focus Mode Extension" --github-issue 42

# Create issues from roadmap
/roadmap export high-priority --create-issues
```

### With Time Tracking
```bash
# Estimate and track time
/roadmap update "Theme Creator" --estimated-hours 40
/roadmap update "Theme Creator" --actual-hours 32
```

## Advanced Usage

### Conditional Commands
```bash
# Show different views based on role
/roadmap show --role developer    # Technical details
/roadmap show --role product      # User impact focus
/roadmap show --role stakeholder  # High level metrics
```

### Smart Suggestions
```bash
# Auto-suggest based on completed work
/roadmap suggest next             # "Based on your recent completions..."

# Detect patterns and recommend
/roadmap analyze patterns         # "You complete UI features 2x faster..."
```

### Collaborative Features
```bash
# Add team member assignments
/roadmap update "Browser Extension" --assigned @arach

# Show team workload
/roadmap show --group-by assignee

# Planning poker integration
/roadmap estimate "Mobile App" --team-session
```

## Tips & Best Practices

### Effective Roadmap Hygiene
- Run `/roadmap analyze` weekly to catch drift
- Use `/roadmap show completed` for motivation
- Keep descriptions concise but compelling
- Regular priority reviews with `/roadmap show high-priority`

### Sprint Integration
- Start sprints with `/roadmap show high-priority --limit 3`
- End sprints with completing items and updating status
- Use timeline analysis for realistic planning

### Communication
- Export completed work for team updates
- Use analytics for stakeholder reports  
- Share high-priority items for alignment

This command system transforms roadmap management from a static document into a dynamic, integrated planning tool!