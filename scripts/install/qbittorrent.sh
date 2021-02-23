#!/bin/bash
# qBittorrent Installer for swizzin
# Author: liara

# Source the required functions
. /etc/swizzin/sources/functions/qbittorrent
. /etc/swizzin/sources/functions/libtorrent
. /etc/swizzin/sources/functions/utils
. /etc/swizzin/sources/functions/fpm

users=($(_get_user_list))

if [[ -n $1 ]]; then
    user=$1
    qbittorrent_user_config ${user}
    if [[ -f /install/.nginx.lock ]]; then
        echo_progress_start "Configuring nginx"
        bash /etc/swizzin/scripts/nginx/qbittorrent.sh
        systemctl reload nginx
        echo_progress_done
    fi
    exit 0
fi

check_libtorrent_rasterbar_method

case $LIBTORRENT_RASTERBAR_METHOD in
    repo)
        apt_install_libtorrent_rasterbar
        apt_install qbittorrent-nox
        ;;
    compile)
        detect_libtorrent_rasterbar_conflict qbittorrent
        whiptail_qbittorrent
        qbittorrent_version_info
        #check_client_compatibility
        install_fpm
        check_swap_on

        if ! skip_libtorrent_qbittorrent; then
            echo_progress_start "Building libtorrent-rasterbar"
            build_libtorrent_qbittorrent
            echo_progress_done "Build completed"
        fi

        echo_progress_start "Building qBittorrent"
        build_qbittorrent
        echo_progress_done
        check_swap_off
        ;;
    *)
        echo_error "LIBTORRENT_RASTERBAR_METHOD must be 'repo' or 'compile'"
        exit 1
        ;;

esac

qbittorrent_service
for user in ${users[@]}; do
    echo_progress_start "Enabling qbittorrent for $user"
    qbittorrent_user_config ${user}
    systemctl enable -q --now qbittorrent@${user} 2>&1 | tee -a $log
    echo_progress_done "Started qbt for $user"
done
if [[ -f /install/.nginx.lock ]]; then
    echo_progress_start "Configuring nginx"
    bash /etc/swizzin/scripts/nginx/qbittorrent.sh
    systemctl reload nginx >> $log 2>&1
    echo_progress_done
fi

touch /install/.qbittorrent.lock
