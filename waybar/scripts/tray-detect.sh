#!/bin/bash
# Show the tray expand icon only when StatusNotifierItems are registered.
# Returns a hidden class when the tray is empty so the button collapses.

ICON=$(printf '\xef\x81\x93')  # U+F053 — same glyph as original expand-icon

items=$(busctl --user get-property org.kde.StatusNotifierWatcher \
    /StatusNotifierWatcher \
    org.kde.StatusNotifierWatcher \
    RegisteredStatusNotifierItems 2>/dev/null)

if echo "$items" | grep -q "StatusNotifierItem"; then
    printf '{"text":"%s"}\n' "$ICON"
else
    printf '{"text":"%s","class":"hidden"}\n' "$ICON"
fi
