#!/bin/sh

# Script created by iet5
# ==========================================================
# SCRIPT : DOWNLOAD AND INSTALL DREAMBOX NTP SYNC
# Notes  : Reads the latest version from ver.txt, downloads and
#          validates the matching DEB, removes earlier time-sync
#          packages and plugin folders, installs, verifies and restarts
#          Enigma2 automatically without asking questions.
# ==========================================================
#
# One-command installation:
# wget -qO- "https://raw.githubusercontent.com/Saiedf/DreamboxNTP/main/installer_dreambox_ntp_sync_auto.sh?nocache=$(date +%s)" | /bin/sh
#
# Alternative:
# wget -O /tmp/installer_dreambox_ntp_sync_auto.sh "https://raw.githubusercontent.com/Saiedf/DreamboxNTP/main/installer_dreambox_ntp_sync_auto.sh?nocache=$(date +%s)" && chmod 755 /tmp/installer_dreambox_ntp_sync_auto.sh && /bin/sh /tmp/installer_dreambox_ntp_sync_auto.sh
# ==========================================================

PACKAGE_NAME='dreambox-ntp-sync'
PLUGIN_TITLE='Dreambox NTP Sync'

REPO_USER='Saiedf'
REPO_NAME='DreamboxNTP'
REPO_BRANCH='main'
VERSION_FILE_PATH='ver.txt'
RELEASES_DIR='Releases'

say() {
    echo "$@"
}

have() {
    command -v "$1" >/dev/null 2>&1
}

trim() {
    printf '%s' "$1" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

download_to_stdout() {
    URL="$1"
    if have wget; then
        wget -T 20 -t 2 -qO- "$URL"
        return $?
    fi
    if have curl; then
        curl -fsL --connect-timeout 15 --max-time 60 --retry 2 "$URL"
        return $?
    fi
    return 1
}

download_file() {
    URL="$1"
    TARGET="$2"
    rm -f "$TARGET" >/dev/null 2>&1
    if have wget; then
        wget -T 25 -t 2 -O "$TARGET" "$URL"
        return $?
    fi
    if have curl; then
        curl -fL --connect-timeout 15 --max-time 120 --retry 2 \
            -o "$TARGET" "$URL"
        return $?
    fi
    return 1
}

validate_package() {
    [ -s "$TEMP_PACKAGE" ] || return 1
    have dpkg-deb || return 1
    dpkg-deb --info "$TEMP_PACKAGE" >/dev/null 2>&1 || return 1
    DOWNLOADED_NAME=$(dpkg-deb -f "$TEMP_PACKAGE" Package 2>/dev/null) || return 1
    DOWNLOADED_VERSION=$(dpkg-deb -f "$TEMP_PACKAGE" Version 2>/dev/null) || return 1
    DOWNLOADED_ARCH=$(dpkg-deb -f "$TEMP_PACKAGE" Architecture 2>/dev/null) || return 1
    [ "$DOWNLOADED_NAME" = "$PACKAGE_NAME" ] || return 1
    [ "$DOWNLOADED_VERSION" = "$PLUGIN_VERSION" ] || return 1
    [ "$DOWNLOADED_ARCH" = 'all' ] || return 1
    return 0
}

fetch_version() {
    VERSION_URL="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$REPO_BRANCH/$VERSION_FILE_PATH?nocache=$(date +%s)"
    VERSION_RAW=$(download_to_stdout "$VERSION_URL" 2>/dev/null | sed -n '1p')
    VERSION_RAW=$(trim "$VERSION_RAW")
    case "$VERSION_RAW" in
        ''|*[!0-9A-Za-z._-]*|.*|-*|_*|*/*|*\\*|*[[:space:]]*) return 1 ;;
    esac
    printf '%s' "$VERSION_RAW"
}

read_first_line() {
    for FILE_PATH in "$@"; do
        if [ -r "$FILE_PATH" ]; then
            sed -n '1p' "$FILE_PATH"
            return 0
        fi
    done
    return 1
}

detect_box_model() {
    MODEL=$(read_first_line /proc/stb/info/boxtype /proc/stb/info/model)
    if [ -z "$MODEL" ] && [ -r /proc/device-tree/model ]; then
        MODEL=$(tr -d '\000' < /proc/device-tree/model 2>/dev/null)
    fi
    [ -z "$MODEL" ] && MODEL=$(hostname 2>/dev/null)
    [ -z "$MODEL" ] && MODEL='unknown'
    printf '%s' "$MODEL"
}

detect_python() {
    for PYTHON_BIN in python3 python python2.7 python2; do
        if have "$PYTHON_BIN"; then
            "$PYTHON_BIN" -c 'import sys; sys.stdout.write("%d.%d" % (sys.version_info[0], sys.version_info[1]))' 2>/dev/null
            return 0
        fi
    done
    printf '%s' 'not-found'
}

package_registered() {
    CANDIDATE="$1"
    dpkg-query -W "$CANDIDATE" >/dev/null 2>&1
}

remove_package() {
    CANDIDATE="$1"
    if ! package_registered "$CANDIDATE"; then
        return 0
    fi
    say "Purging old or incomplete package: $CANDIDATE"
    DREAMBOX_NTP_UI_REMOVE=1 dpkg --purge "$CANDIDATE" || return 1
}

remove_version_1_0_traces() {
    say 'Cleaning known stale time-sync files and plugin folders...'

    if [ -d /run/systemd/system ] && have systemctl; then
        systemctl stop merlin-ntp-sync.timer >/dev/null 2>&1 || true
        systemctl disable merlin-ntp-sync.timer >/dev/null 2>&1 || true
        systemctl stop merlin-ntp-sync.service >/dev/null 2>&1 || true
        systemctl stop dreambox-ntp-sync.timer >/dev/null 2>&1 || true
        systemctl disable dreambox-ntp-sync.timer >/dev/null 2>&1 || true
        systemctl stop dreambox-ntp-sync.service >/dev/null 2>&1 || true
        systemctl stop dreambox-ntp-sync-retry.service >/dev/null 2>&1 || true
    fi

    for OLD_FILE in \
        /usr/bin/merlin-ntp-sync \
        /usr/lib/merlin-ntp-sync.py \
        /usr/lib/merlin-ntp-sync.pyc \
        /lib/systemd/system/merlin-ntp-sync.service \
        /lib/systemd/system/merlin-ntp-sync.timer \
        /etc/systemd/system/enigma2.service.d/10-merlin-ntp-sync.conf \
        /etc/rcS.d/S39merlin-ntp-sync \
        /tmp/merlin-ntp-sync.log \
        /etc/enigma2/settings.merlin-ntp.tmp \
        /usr/bin/dreambox-ntp-sync \
        /usr/lib/dreambox-ntp-sync.py \
        /usr/lib/dreambox-ntp-sync.pyc \
        /lib/systemd/system/dreambox-ntp-sync.service \
        /lib/systemd/system/dreambox-ntp-sync-retry.service \
        /lib/systemd/system/dreambox-ntp-sync.timer \
        /etc/systemd/system/enigma2.service.d/10-dreambox-ntp-sync.conf \
        /etc/rcS.d/S39dreambox-ntp-sync \
        /tmp/dreambox-ntp-sync.log \
        /tmp/dreambox-ntp-sync.lock \
        /tmp/dreambox-ntp-sync_1.0.0_all.deb
    do
        if [ -e "$OLD_FILE" ] || [ -L "$OLD_FILE" ]; then
            say "Removing old file: $OLD_FILE"
            rm -f "$OLD_FILE" || return 1
        fi
    done

    for OLD_CACHE in \
        /usr/lib/__pycache__/merlin-ntp-sync*.pyc \
        /usr/lib/__pycache__/dreambox-ntp-sync*.pyc
    do
        if [ -e "$OLD_CACHE" ]; then
            rm -f "$OLD_CACHE" || return 1
        fi
    done

    if [ -d /run/systemd/system ] && have systemctl; then
        systemctl daemon-reload || return 1
        systemctl reset-failed merlin-ntp-sync.service >/dev/null 2>&1 || true
        systemctl reset-failed dreambox-ntp-sync.service >/dev/null 2>&1 || true
        systemctl reset-failed dreambox-ntp-sync-retry.service >/dev/null 2>&1 || true
    fi

    return 0
}

remove_old_versions() {
    remove_package "$PACKAGE_NAME" || return 1
    remove_package 'enigma2-plugin-systemplugins-dreamtimesync' || return 1
    remove_package 'enigma2-plugin-extensions-dreamtimesync' || return 1
    remove_version_1_0_traces || return 1

    for OLD_PLUGIN_PATH in \
        /usr/lib/enigma2/python/Plugins/SystemPlugins/DreamTimeSync \
        /usr/lib/enigma2/python/Plugins/Extensions/DreamTimeSync \
        /usr/lib/enigma2/python/Plugins/Extensions/DreamboxNTP
    do
        if [ -d "$OLD_PLUGIN_PATH" ]; then
            say "Removing old plugin directory: $OLD_PLUGIN_PATH"
            rm -rf "$OLD_PLUGIN_PATH" || return 1
        fi
    done
    return 0
}

install_package() {
    dpkg -i --force-overwrite "$TEMP_PACKAGE"
}

verify_installation() {
    [ -x /usr/bin/dreambox-ntp-sync ] || return 1
    INSTALLED_VERSION=$(/usr/bin/dreambox-ntp-sync --version 2>/dev/null)
    case "$INSTALLED_VERSION" in
        *"$PLUGIN_VERSION"*) ;;
        *) return 1 ;;
    esac

    if [ -d /run/systemd/system ] && have systemctl; then
        systemctl daemon-reload || return 1
        systemctl enable dreambox-ntp-sync.timer >/dev/null 2>&1 || return 1
        systemctl restart dreambox-ntp-sync.timer || return 1
        systemctl start dreambox-ntp-sync.service || true
    else
        /usr/bin/dreambox-ntp-sync --quick || true
    fi
    return 0
}

show_success_popup() {
    MESSAGE_TEXT="Dreambox%20NTP%20Sync%20$PLUGIN_VERSION%20installed%20successfully.%0AAutomatic%20time%20synchronization%20is%20active.%0AThe%20receiver%20will%20reboot%20now."
    if have wget; then
        wget -T 3 -t 1 -qO- "http://127.0.0.1/web/message?text=$MESSAGE_TEXT&type=1&timeout=8" >/dev/null 2>&1
    elif have curl; then
        curl -fs --connect-timeout 3 --max-time 5 \
            "http://127.0.0.1/web/message?text=$MESSAGE_TEXT&type=1&timeout=8" >/dev/null 2>&1
    fi

    if have dbus-send; then
        dbus-send --system --type=method_call \
            --dest=org.freedesktop.Notifications \
            /org/freedesktop/Notifications \
            org.freedesktop.Notifications.Notify \
            string:"$PLUGIN_TITLE" uint32:0 string:"" \
            string:"Installation completed" \
            string:"$PLUGIN_TITLE version $PLUGIN_VERSION installed successfully. The receiver will reboot now." \
            array:string: dict:string:variant: int32:8000 >/dev/null 2>&1
    fi
    sleep 8
}

show_success_table() {
    say ''
    say '============================================================='
    printf '= %-57s =\n' 'INSTALLATION COMPLETED SUCCESSFULLY'
    printf '= %-57s =\n' "Dreambox NTP Sync version $PLUGIN_VERSION is now active."
    printf '= %-57s =\n' 'Plugin created by iet5'
    printf '= %-57s =\n' 'The receiver will reboot automatically in 5 seconds.'
    say '============================================================='
    say ''
}

reboot_receiver() {
    sync
    sleep 5
    if [ -d /run/systemd/system ] && have systemctl; then
        systemctl reboot || reboot
    else
        reboot
    fi
}

if [ "$(id -u 2>/dev/null)" != 0 ]; then
    say 'This installer must be run as root.'
    exit 1
fi

if ! have dpkg || ! have dpkg-query || ! have dpkg-deb; then
    say 'This installer requires a Dreambox image with dpkg and DEB support.'
    exit 1
fi

if ! have wget && ! have curl; then
    say 'This installer requires wget or curl.'
    exit 1
fi

PLUGIN_VERSION=$(fetch_version)
if [ $? -ne 0 ] || [ -z "$PLUGIN_VERSION" ]; then
    say 'Failed to read a valid version from ver.txt.'
    exit 1
fi

PACKAGE_TYPE='deb'
PACKAGE_FILE="${PACKAGE_NAME}_${PLUGIN_VERSION}_all.deb"
PACKAGE_URL="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$REPO_BRANCH/$RELEASES_DIR/$PACKAGE_FILE?nocache=$(date +%s)"
TEMP_PACKAGE="/tmp/$PACKAGE_FILE"
cleanup_temp_package() {
    rm -f "$TEMP_PACKAGE" >/dev/null 2>&1
}
trap cleanup_temp_package 0
trap 'exit 1' HUP INT TERM
BOX_MODEL=$(detect_box_model)
ARCH=$(uname -m 2>/dev/null)
PYTHON_VERSION=$(detect_python)

say ''
say '*************************************************************'
say '**                         STARTED                         **'
say '*************************************************************'
say '** Plugin created by iet5                                  **'
say "** Plugin       : $PLUGIN_TITLE"
say "** Version      : $PLUGIN_VERSION"
say "** Model        : $BOX_MODEL"
say "** Architecture : $ARCH"
say "** Python       : $PYTHON_VERSION"
say "** Package type : $PACKAGE_TYPE"
say "** Package file : $PACKAGE_FILE"
say '*************************************************************'
say ''

say 'Downloading the installation package...'
say "$PACKAGE_URL"
if ! download_file "$PACKAGE_URL" "$TEMP_PACKAGE"; then
    say 'Download failed. Installation was not changed.'
    exit 1
fi

say 'Validating the downloaded DEB package...'
if ! validate_package; then
    say 'Downloaded package validation failed; installation aborted.'
    exit 1
fi

say ''
say 'Removing earlier versions and cleaning old plugin folders...'
if ! remove_old_versions; then
    say 'Failed to remove an earlier version. Installation aborted.'
    exit 1
fi

say ''
say 'Installing the new package...'
if ! install_package; then
    say 'Installation failed.'
    exit 1
fi

say ''
say 'Verifying the service and automatic timer...'
if ! verify_installation; then
    say 'Installation verification failed.'
    exit 1
fi

if [ -f /tmp/dreambox-ntp-sync.log ]; then
    say ''
    say 'Latest synchronization result:'
    tail -n 5 /tmp/dreambox-ntp-sync.log
fi
date

cleanup_temp_package
trap - 0 HUP INT TERM
sync

say ''
show_success_popup
show_success_table
reboot_receiver

exit 0
