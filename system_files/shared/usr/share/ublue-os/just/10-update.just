# vim: set ft=make :

alias upgrade := update

# Update system, flatpaks, and containers all at once
update:
    #!/usr/bin/bash
    # rpm-ostree used due to bootc upgrade not supporting local layered packages
    rpm-ostree upgrade
    # Updates system Flatpaks
    if flatpak remotes | grep -q system; then
        flatpak update -y
    fi
    # Update user Flatpaks
    if flatpak remotes | grep -q user; then
        flatpak update --user -y
    fi
    # Guard Brew if the user does not own brew/doesn't exist
    if [[ -O /var/home/linuxbrew/.linuxbrew/bin/brew ]]; then
        # Upgrade will run brew update if needed
        /var/home/linuxbrew/.linuxbrew/bin/brew upgrade
    fi

alias auto-update := toggle-updates

# Turn automatic updates on or off
toggle-updates ACTION="prompt":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    CURRENT_STATE="Disabled"
    if systemctl is-enabled ublue-update.timer | grep -q enabled; then
        CURRENT_STATE="Enabled"
    fi
    OPTION={{ ACTION }}
    if [ "$OPTION" == "prompt" ]; then
        echo "Automatic updates are currently: ${bold}${CURRENT_STATE}${normal}"
        echo "Enable or Disable automatic updates?"
        OPTION=$(ugum choose Enable Disable)
    elif [ "$OPTION" == "help" ]; then
        echo "Usage: ujust toggle-updates <option>"
        echo "  <option>: Specify the quick option - 'enable' or 'disable'"
        echo "  Use 'enable' to Enable automatic updates."
        echo "  Use 'disable' to Disable automatic updates."
        exit 0
    fi
    if [ "${OPTION,,}" == "enable" ]; then
        sudo systemctl enable ublue-update.timer
    elif [ "${OPTION,,}" == "disable" ]; then
        sudo systemctl disable ublue-update.timer
    fi

alias changelog := changelogs

# Show the changelog
changelogs:
    #!/usr/bin/bash

    # Get Image Tag
    TAG=$(jq -r '.["image-tag"]' < /usr/share/ublue-os/image-info.json)

    # If stable or gts, get changelogs from Github Releases
    if [[ "$TAG" =~ gts$|stable$ ]]; then
        DATE="$(grep -oP "OSTREE_VERSION=.*\d{2}\.\K\d{8}[.0-9]*" /etc/os-release)"
        CONTENT=$(curl -Ls https://api.github.com/repos/ublue-os/bluefin/releases | jq -r ".[] | select(.tag_name==\"${TAG}-${DATE}\") | .body")
    fi

    # Display Content with Glow, otherwise fallback to rpm-ostree changelogs (stable-daily/latest/desynced)
    if [[ -n "${CONTENT:-}" ]]; then
        echo "$CONTENT" | glow -p
    else
        ujust changelogs-fedora
    fi

changelogs-fedora:
    rpm-ostree db diff --changelogs
