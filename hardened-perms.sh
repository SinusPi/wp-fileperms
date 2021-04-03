#!/bin/bash

# Simple Wordpress permissions lock.
# Requirement: your webserver needs to run under different permissions than
# the account owner.
# Sets the following folder permissions:
# * Content upload folders (wp-content/uploads)
#    - WRITABLE for proper day-to-day operation,
# * Code folders (wp-include, wp-admin, wp-content/* except uploads)
#    - NOT WRITABLE by the server process under any circumstances.
# Also, a .htaccess file is installed to prevent running .php files
# in the upload folders, as that's the primary target of exploits.
# As a result your WordPress should be (hopefully) safe against PHP file
# drops and overwrites - but at the cost of not being able to install or
# update any plugins or core files. You'll need to unlock your WordPress
# installation before doing that, and re-lock it afterwards. It's like
# turning a key in a lock.


echo Wordpress File Permission Hardener v0.1  (cl) Sinus
echo

if [[ ! -f wp-config.php ]]; then
        echo "ERROR: You need to run this script from the main WordPress folder."
        exit
fi

function re_lock() {
        echo ""
        echo "For safety's sake, I'll wait for one hour, then I'll lock it all again."
        echo "Hit ENTER to lock it when you're done."
        echo "Hit ^C if you want to leave it all open and vulnerable, but for your sake, remember to lock it again."

        function aborting() {
                trap - INT
                echo ""
                echo "^C pressed. Very well, you know the risks, you know where to find me. Good luck out there."
                exit
        }
        function nohup() {
                :
        }

        trap aborting INT
        trap nohup SIGHUP

        echo -n "Waiting for an hour... "
        read -t 3600 && echo Locking down now. && $0 --relock
        exit
}

[[ "$1" == "--brief" || "$2" == "--brief" ]] && BRIEF=1 || BRIEF=0

if [[ -z "$1" || "$1" == "--help" ]]; then
        cat <<EOF
Command line parameters:

        --lock, -l  - lock everything
        --unlock-plugins, -u  - unlock the plugins folder
        --unlock-everything, -U  - unlock everything
EOF
elif [[ $1 == "--lock" || $1 == "-l" ]]; then
        echo "Hardening Wordpress in progress."

        HTA=./wp-content/.htaccess

        echo "Locking out .php files using $HTA ..."
        if grep -q HardenedPerms $HTA; then
                echo $HTA present and looks good at first glance.
        else
                echo -n >>$HTA || ( chmod +w $HTA; echo -n >>$HTA ) || ( echo "Can't write to $HTA, that's worrying. Aborting!" ; exit )
                cat <<EOF >>$HTA
# HardenedPerms: no access to any PHP files here.
RewriteRule .*\.php - [R=404,NC,L]
EOF
                if grep HardenedPerms $HTA; then echo "All right, .php files locked out." ; else echo "ERROR! Failed to write to $HTA!"; exit; fi
        fi

        echo "Removing write permissions from WP files..."
        chmod -R a-w *.php wp-*

        echo "Well, except wp-content/uploads ..."
        chmod -R +w wp-content/uploads

        chmod +w $0

        echo "Done. Note that you won't be able to perform auto-updates or edit theme or plugin files from within WordPress admin screens anymore."

elif [[ $1 == "--relock" ]]; then

        chmod -R o-w *.php wp-*
        chmod -R o+w wp-content/uploads
        chmod +w $0

        echo "Write access is locked again. See you next time."

elif [[ $1 == "--unlock-plugins" || $1 == "-u" ]]; then

        echo "Unlocking permissions for updating/installing plugins..."

        chmod -R o+w wp-content

        echo "Done. Install or update your plugins now, but be quick about it."

        re_lock

elif [[ $1 == "--unlock-everything" || $1 == "-U" ]]; then

        echo "Unlocking write permissions for EVERYTHING..."

        chmod -R o+w .

        echo "Done. All file write permissions granted. Perform updates or whatever, but be VERY quick about it. Your WordPress is completely vulnerable now."

        re_lock

else
        echo "Unknown parameters."
fi
