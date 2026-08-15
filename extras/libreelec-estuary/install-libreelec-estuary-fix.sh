#!/bin/sh
set -eu

system_xml=/usr/share/kodi/addons/skin.estuary/xml/Custom_1109_TopBarOverlay.xml
override_dir=/storage/.config/kodi-overrides
override_xml=$override_dir/Custom_1109_TopBarOverlay.xml
unit=/storage/.config/system.d/kodi-hide-seek-header.service
temporary_xml=$override_dir/.Custom_1109_TopBarOverlay.xml.$$

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this installer as root on LibreELEC." >&2
    exit 1
fi

if [ ! -f "$system_xml" ]; then
    echo "Stock Estuary was not found. Nothing was changed." >&2
    exit 1
fi

if systemctl is-active --quiet kodi-hide-seek-header.service 2>/dev/null; then
    systemctl stop kodi-hide-seek-header.service
fi

mkdir -p "$override_dir" /storage/.config/system.d
trap 'rm -f "$temporary_xml"' EXIT

awk '
    { print }
    !done && /<control type="group">/ {
        print "\t\t\t<visible>String.IsEmpty(Window(10000).Property(script.plex.is_active))</visible>"
        done = 1
    }
    END { if (!done) exit 1 }
' "$system_xml" > "$temporary_xml"

mv "$temporary_xml" "$override_xml"
trap - EXIT

printf '%s\n' \
    '[Unit]' \
    'Description=Hide Estuary seek header while PlexMod is active' \
    'Before=kodi.service' \
    '' \
    '[Service]' \
    'Type=oneshot' \
    'ExecStart=/bin/mount --bind /storage/.config/kodi-overrides/Custom_1109_TopBarOverlay.xml /usr/share/kodi/addons/skin.estuary/xml/Custom_1109_TopBarOverlay.xml' \
    'ExecStop=/bin/umount /usr/share/kodi/addons/skin.estuary/xml/Custom_1109_TopBarOverlay.xml' \
    'RemainAfterExit=yes' \
    '' \
    '[Install]' \
    'WantedBy=kodi.service' > "$unit"

systemctl daemon-reload
systemctl enable --now kodi-hide-seek-header.service
systemctl restart kodi

echo "Installed. Estuary's blue seek header is now hidden only inside PlexMod."
