#!/bin/bash
##
# Start the RPCEmu system.

export DISPLAY=:1
export USER=riscos

# Prevent the startup from reporting that it cannot use hardware drivers
export LIBGL_ALWAYS_SOFTWARE=1

# Ensure that we have a runtime directory
export XDG_RUNTIME_DIR=$HOME/.run
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Start the VNC server
vncserver -name "RPCEmu $RPCEMU_VERSION, RISC OS $RO_VERSION" \
          -geometry 1280x1024 \
          -localhost no \
          >/dev/null 2>/dev/null

# Once a second update the resolution of the session.
(
    while true ; do
        sleep 1
        if [[ -f /riscos/_Resolution,ffd ]] ; then
            rpcemu-sync-size.sh
        fi
    done
) &
disown

if [[ "$RO_VERSION" = "5" ]] && [[ "$RO5_BETA" -eq 1 ]]; then
    echo "Installing ROOL RISC OS 5 beta ROM and HardDisc4..."

    TMP=$(mktemp -d)

    wget -qO- 'https://api.github.com/repos/david-ramsden/unzip-riscos/releases/latest' \
        | grep -oP '"browser_download_url":\s*"\Khttps://[^"]+' \
        | grep "$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')" \
        | wget -i - -qO "$TMP/unzip-riscos"
    if [ $? -ne 0 ]; then
        echo "Unable to download unzip-riscos. Aborting."
        exit 1
    fi

    chmod 755 "$TMP/unzip-riscos"

    ROM_ZIP=$(wget -qO- 'https://www.riscosopen.org/content/downloads/riscpc' | grep -oP '(?<=<a name="beta_iomd_softload" href=")[^"]+')
    if [[ -z "$ROM_ZIP" ]]; then
        echo "ROM zip not discovered. Aborting."
        exit 1
    fi

    wget -qO "$TMP/rom.zip" "https://www.riscosopen.org$ROM_ZIP"
    if [ $? -ne 0 ]; then
        echo "Unable to download ROM zip. Aborting."
        exit 1
    fi

    rm -f /riscos-roms/*
    unzip -q -j "$TMP/rom.zip" 'soft/!Boot/Resources/SoftLoad/riscos' -d /riscos-roms/

    wget -qO "$TMP/harddisc4.zip" 'https://www.riscosopen.org/zipfiles/platform/common/HardDisc4.zip'
    if [ $? -ne 0 ]; then
        echo "Unable to download HardDisc4 zip. Aborting."
        exit 1
    fi

    "$TMP/unzip-riscos" "$TMP/harddisc4.zip" "$TMP"
    rsync -a "$TMP/HardDisc4/"* /riscos/

    rm -rf "$TMP"
fi

cd /rpcemu
if [[ -x rpcemu-recompiler ]] ; then
    rpcemu=rpcemu-recompiler
else
    rpcemu=rpcemu-interpreter
fi
./"${rpcemu}"
