#!/bin/bash
current=$(hyprctl getoption general:layout | awk '/^str:/ { print $2 }')

if [ "$current" = "scrolling" ]; then
    hyprctl keyword general:layout dwindle
else
    hyprctl keyword general:layout scrolling
fi
