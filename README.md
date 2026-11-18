# window-close-confirm-popup

Quick script that shows a popup requiring confirmation when closing a window.
Allows costumization and whitelisting / blacklisting apps.

I have it set to alt+F4 so I can be sure that no important unsaved documents are lost.

Very personalized for my usecase.

### How to use:

**Pass no arguments to run the script:**
```bash
./window-close-confirm-popup.sh
```
Recomend to set this command to a keybind because running this in terminal will just close terminal
        


**Costumizing settings (pass arguments):**

To open settings gui:
```bash
./window-close-confirm-popup.sh -config
```
To change whitelisted apps:
```bash
./window-close-confirm-popup.sh -whitelist "new list"
```

To change time before popup auto-closes:
```bash
./window-close-confirm-popup.sh -timeout "new time"
```

To change mode:
```bash
./window-close-confirm-popup.sh -mode "new mode"
```
Possible modes:
* "-n" = never ask (no popup)
* "-w" = ask only for apps NOT in WHITELIST
* "-b" = ask only for apps IN WHITELIST
* "-a" = always ask (ignore whitelist)

### Requirements:

Since this is a personalized setup, it assumes you have the following installed on your Linux system:
* xdotool (get active window ID)
* xprop (x11-utils — read WM_CLASS)
* wmctrl (close the window)
* Zenity (confirmation popup)
* Yad (config GUI)
* libnotify (notify-send — save confirmation)