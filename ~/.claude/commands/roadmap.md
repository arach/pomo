# Roadmap Management (User Command)

A universal command for managing ROADMAP.md files across all projects.

## Usage

Use `/user:roadmap` followed by actions to interact with any project's roadmap.

## Available Actions

### Show roadmap sections
- `/user:roadmap show` - Display entire roadmap
- `/user:roadmap show completed` - Show completed features only
- `/user:roadmap show planned` - Show planned features
- `/user:roadmap show high-priority` - Show high priority items

### Add new items
- `/user:roadmap add "Feature Name"` - Add new feature to planned section
- `/user:roadmap add "Feature Name" --priority high` - Add with priority

### Update status
- `/user:roadmap complete "Feature Name"` - Mark feature as completed
- `/user:roadmap start "Feature Name"` - Move to in-progress

### Analytics
- `/user:roadmap analyze` - Show roadmap analytics and progress
- `/user:roadmap timeline` - Estimate timeline for remaining work

## Implementation

When you use these commands, I will:

1. Look for ROADMAP.md in the current project (ROADMAP.md, docs/ROADMAP.md, etc.)
2. Parse the markdown structure to extract features and status
3. Perform the requested action with rich formatting
4. Update the ROADMAP.md file if changes were made
5. Provide next steps and recommendations

## Examples

```
/user:roadmap show high-priority
```
Shows high priority features with status, effort, and impact.

```
/user:roadmap complete "Session Statistics Dashboard"
```
Moves feature to completed section and updates the file.

```
/user:roadmap add "Mobile App Support" --priority medium
```
Adds new feature to planned section.

This command works across all your projects that have ROADMAP.md files, making roadmap management consistent everywhere!