on run argv
    tell application "Finder"
        tell disk "OpenLid Install"
            open
            delay 1
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set bounds of container window to {180, 160, 840, 580}
            set viewOptions to icon view options of container window
            set arrangement of viewOptions to not arranged
            set icon size of viewOptions to 100
            set text size of viewOptions to 14
            set background picture of viewOptions to file ".background:installer.png"
            set position of item "OpenLid.app" to {170, 205}
            set position of item "Applications" to {490, 205}
            close
            open
            update without registering applications
            delay 2
            close
        end tell
    end tell
end run
