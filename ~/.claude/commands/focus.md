# Focus Management

Manage your current focus and context switching across projects.

## Usage

`/user:focus` - Manage what you're currently focused on

## Available Actions

- `/user:focus` - Show current focus and active work
- `/user:focus set "Project: Task"` - Set current focus
- `/user:focus switch "Project: Task"` - Switch focus (logs previous)
- `/user:focus break` - Take a break (pause current focus)
- `/user:focus resume` - Resume previous focus

## What it does

Tracks your current focus context to help with:
- Context switching overhead
- Time allocation across projects  
- Maintaining momentum on specific work
- Recording focus patterns for optimization

## Example Output

```
🎯 Current Focus

Active: Pomo: Session Statistics Dashboard
Started: 2 hours ago
Project: Pomo (High priority)
Next: Complete UI wireframes

Recent Context Switches:
- Other-App: Bug fix (30 min)
- Pomo: Statistics work (resumed)
- Side-Project: Planning (15 min)

Recommendations:
- You've been focused for 2h - consider a break
- Low context switching today (good momentum!)
- Pomo statistics work has high priority
```

Helps you stay intentional about focus and minimize costly context switches.