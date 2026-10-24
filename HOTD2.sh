#!/bin/bash
# PortMaster launcher for HOTD2RE (The House of the Dead 2, native rebuild).

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source $controlfolder/control.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

GAMEDIR=/$directory/ports/hotd2
cd $GAMEDIR

> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# The game data is Sega's: the player brings the "game" folder of the HOTD2RE Windows release.
if [ ! -f "$GAMEDIR/game/Hod2.exe" ]; then
  echo "Missing game files: copy the game folder of the HOTD2RE Windows release into $GAMEDIR/game (see README.md)."
  sleep 8
  pm_finish
  exit 1
fi

$ESUDO chmod +x "$GAMEDIR/play"

# The game aims at the mouse pointer and fires with the mouse buttons: gptokeyb turns the sticks and shoulder buttons
# into a virtual mouse (hotd2.gptk).
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

$GPTOKEYB "play" -c "$GAMEDIR/hotd2.gptk" &
pm_platform_helper "$GAMEDIR/play" >/dev/null

./play game --renderer gles --input mouse

pm_finish
