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

## Implementation

When you use these commands, I will:

1. Read the current ROADMAP.md file
2. Parse the markdown structure to extract features and status
3. Perform the requested action (show, add, update, analyze)
4. Update the ROADMAP.md file if changes were made
5. Provide formatted output with progress and next steps

## Examples

```
/project:roadmap show high-priority
```
Would show all high priority features from the roadmap with their current status.

```
/project:roadmap complete "Session Statistics Dashboard"
```
Would move the Session Statistics Dashboard from planned/in-progress to completed section.

```
/project:roadmap add "Mobile App Support" --priority medium
```
Would add a new feature to the planned section with medium priority.

This provides a clean interface for roadmap management while following Claude Code's actual slash command conventions.