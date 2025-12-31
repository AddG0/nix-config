# Browser MCP

Automate the user's browser via the Browser MCP Chrome extension.

## Tools

- `browser_navigate` - Go to URL
- `browser_snapshot` - Get page accessibility tree (use first to find elements)
- `browser_click` / `browser_type` / `browser_hover` - Interact with elements
- `browser_screenshot` - Capture the page
- `browser_go_back` / `browser_go_forward` - Navigation history
- `browser_wait` / `browser_press_key` - Timing and keyboard
- `browser_drag` - Drag and drop
- `browser_console_logs` - Debug output

## Usage

1. Use `browser_snapshot` first to understand page structure
2. Target elements using labels/selectors from the snapshot
3. Take screenshots for visual confirmation
