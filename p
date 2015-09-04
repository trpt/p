#!/bin/bash

# Wrapper for pass by Trepet
# © GPLv3

# Path to the app, do not edit, use $SCR below to make program portable !experimental!
SCR="$( cd "$(dirname "$0")" ; pwd -P )"

# GPG keys and config homedir, e.g. "$HOME/.gnupg"
GNUPGHOME="$HOME/.gnupg"

# Location of pass folder tree, e.g. "$HOME/.password-store"
PASS_HOME="$HOME/.password-store"

# GPG encryption key(s)
PASSWORD_STORE_KEY='0xXXXXXXXX'

# Options to password generation, check pass help
GENOPTS='--no-symbols'

# Password length when generating
GENLEN='28'

# Path to editor apps
EDITOR_X='gedit'
EDITOR_CONSOLE='nano'

# apps defaults
rofi_cmd () {
rofi -dmenu -bg \#222222 -fg \#ffffff -hlbg \#222222 -hlfg \#11dd11 -opacity 90 -lines 20 -width -35 -no-levenshtein-sort -disable-history -p pass: -mesg "$rofi_mesg"
}

dmenu_cmd () {
dmenu -l 20 -b -nb \#222222 -nf \#ffffff -sb \#222222 -sf \#11dd11 $@
}

zenity_size="--width=500 --height=300"

# Terminal emulator, not usable yet
# TERMEMU='sakura -x'

# You usually don't need to edit anything below this line #
###########################################################
TMPDIR='/dev/shm'
PASS_HOME_BASENAME="$(basename $PASS_HOME)"
PASS_HOME_DIRNAME="$(dirname $PASS_HOME)"
PASS_HOME_UNPACKED="$TMPDIR/$PASS_HOME_BASENAME"
ENCRYPTED_FILENAME="$PASS_HOME_DIRNAME/$PASS_HOME_BASENAME.tar.gpg"
PASSWORD_STORE_DIR="$PASS_HOME"
DATE="$(date +%Y-%m-%d-%Hh)"
PROGRAM="${0##*/}"
PROGRAM_ABS="$SCR/$PROGRAM"
BACKUPDIR="$PASS_HOME_DIRNAME"
[[ -n $DISPLAY && $XDG_VTNR -eq 1 ]] && export EDITOR="$EDITOR_X" || export EDITOR="$EDITOR_CONSOLE"

rofi_default_mesg='<b>Copy pass to clipboard</b>'
rofi_show_mesg='<b>Show password</b>'
rofi_type_mesg='<b>Type password</b>'
rofi_edit_mesg='<b>Edit password</b>'
rofi_del_mesg='<b>Delete password</b>'

usage() {
  cat <<EOF

password-store wrapper by Trepet

usage: $PROGRAM action

  action:
    encdb, e - encrypt existing password-store directory
    backup, b - backup existing encrypted database
    open, o - decrypt database and extract it to $PASS_HOME_UNPACKED
    close, c - encrypt database at $PASS_HOME_UNPACKED and save it to $ENCRYPTED_FILENAME
    dmenu, d - use dmenu to list, choose password and copy it to clipboard
    rofi, r - use rofi to list, choose password and copy it to clipboard
    gen, g - generate pass using zenity as prompt for new entry

  dmenu or rofi action parameters:
    --type, -t, t - use xdotool to autotype password
    --show, -s, s - use zenity to show content
    --edit, -e, e - edit chosen entry with $EDITOR
    --del,  -d, d - delete entry without warning

  Examples:
    $PROGRAM backup
    $PROGRAM dmenu
    $PROGRAM rofi --type
    $PROGRAM d -e
    $PROGRAM r s

  Config (check source)
    GPG home dir:
    $GNUPGHOME

    GPG key(s) to encrypt:
    $PASSWORD_STORE_KEY

    encrypted password-store database:
    $ENCRYPTED_FILENAME

    editor:
    $EDITOR
EOF
}

if [[ $1 = @(-h|--help) ]]; then
  usage
  exit $(( $# ? 0 : 1 ))
fi

encdb () {
  if [[ -d "$PASS_HOME" ]]; then
    if [[ -f "$ENCRYPTED_FILENAME" ]]; then
      echo "File $ENCRYPTED_FILENAME exists, aborting..."
      exit 1
    fi
    chmod -R go-rwx "$PASS_HOME" && \
    tar --preserve-permissions -C "$PASS_HOME_DIRNAME" -c "$PASS_HOME_BASENAME" | \
    gpg --encrypt -r "$PASSWORD_STORE_KEY" > "$ENCRYPTED_FILENAME" || exit 1
  else
    echo -e "Password-store folder does not exist, check config"
    exit 1
  fi
}

backup () {
  if [[ -f "$ENCRYPTED_FILENAME" ]]; then
    cp "$ENCRYPTED_FILENAME" "$BACKUPDIR"/"${PASS_HOME_BASENAME}_$DATE.tar.gpg" || exit 1
  else
    echo -e "Encrypted database does not exist, run \"$PROGRAM_ABS encdb\" command fisrt"
    exit 1
  fi
}

tarcmd () {
  if [[ -d "$PASS_HOME_UNPACKED" ]]; then
    tar --preserve-permissions -C "$TMPDIR" --remove-files -c "$PASS_HOME_BASENAME" | \
    gpg --encrypt -r "$PASSWORD_STORE_KEY" > "$ENCRYPTED_FILENAME" || exit 1
  else
    echo -e "Unpacked dir does not exist"
    exit 1
  fi
}

untarcmd () {
  if [[ -f "$ENCRYPTED_FILENAME" ]]; then
    gpg -d "$ENCRYPTED_FILENAME" | tar -x --preserve-permissions -C "$TMPDIR"/ || exit 1
  else
    echo -e "Encrypted database does not exist, run \"$PROGRAM_ABS encdb\" command fisrt"
    exit 1
  fi
}

deldb () {
  rm -rf "$PASS_HOME_UNPACKED"
  echo "No changes made"
}

case $1 in
    encdb | e)
      encdb && \
      echo -e " $ENCRYPTED_FILENAME created \n You can backup and delete $PASS_HOME folder now" || \
      echo "Could not create database, check config in source of $PROGRAM_ABS"
    ;;

    backup | b)
      backup && \
      echo -e " $BACKUPDIR/${PASS_HOME_BASENAME}_$DATE.tar.gpg created"
    ;;

    open | o)
      untarcmd
    ;;

    close | c)
      tarcmd
    ;;

    gen | g)
      newentry=$(zenity  --title "New password" --entry --text= || exit 1)
      [[ -n $newentry ]] && "$PROGRAM_ABS" generate "$GENOPTS" "$newentry" $GENLEN &>/dev/null
    ;;

    rofi | dmenu | r | d)
      if [[ $1 == "rofi" || $1 == "r" ]]; then
        menu="rofi_cmd"
        rofi_mesg=$rofi_default_mesg
      elif [[ $1 == "dmenu" || $1 == "d" ]]; then
        menu="dmenu_cmd"
      fi
      shopt -s nullglob globstar
      export PASSWORD_STORE_DIR="$PASS_HOME_UNPACKED"
      typeit=0
      showit=0
      editit=0
      delit=0
      shift

      if [[ $1 == "--type" || $1 == "-t" || $1 == "t" ]]; then
        typeit=1
        [[ $menu == rofi_cmd ]] && rofi_mesg="$rofi_type_mesg"
        shift
      fi

      if [[ $1 == "--show" || $1 == "-s" || $1 == "s" ]]; then
        showit=1
        [[ $menu == rofi_cmd ]] && rofi_mesg="$rofi_show_mesg"
        shift
      fi

      if [[ $1 == "--edit" || $1 == "-e" || $1 == "e" ]]; then
        #notify-send pass "You are about to edit password entry"
        editit=1
        [[ $menu == rofi_cmd ]] && rofi_mesg="$rofi_edit_mesg"
        shift
      fi

      if [[ $1 == "--del" || $1 == "-d" || $1 == "d" ]]; then
        notify-send pass "You are about to remove password entry! This cannot be undone" -h string:sound-name:message-new-email
        delit=1
        [[ $menu == rofi_cmd ]] && rofi_mesg="$rofi_del_mesg"
        shift
      fi

      "$PROGRAM_ABS" open
      password_files=( "$PASSWORD_STORE_DIR"/**/*.gpg )
      password_files=( "${password_files[@]#$PASSWORD_STORE_DIR/}" )
      password_files=( "${password_files[@]%.gpg}" )
      password=$(printf '%s\n' "${password_files[@]}" | sort -f | $menu "$@")
      "$PROGRAM_ABS" close

      [[ -n $password ]] || exit

      if [[ $typeit -eq 0 && $showit -eq 0 && $editit -eq 0 && $delit -eq 0 ]]; then
        "$PROGRAM_ABS" show -c "$password" 2>/dev/null
      elif [[ $typeit -eq 1 ]] ;then
        "$PROGRAM_ABS" show "$password" |
        awk 'BEGIN{ORS=""} {print; exit}' |
        xdotool type --clearmodifiers --file -
      elif [[ $showit -eq 1 ]]; then
        "$PROGRAM_ABS" show "$password" | zenity $zenity_size --text-info --title="$password"
      elif [[ $editit -eq 1 ]]; then
        "$PROGRAM_ABS" edit "$password"
      elif [[ $delit -eq 1 ]]; then
        "$PROGRAM_ABS" rm -f "$password" &>/dev/null
      fi
    ;;

    *)
      export PASSWORD_STORE_DIR="$PASS_HOME_UNPACKED"
      if [[ ! -d "$PASS_HOME_UNPACKED" ]]; then
        untarcmd
        pass $@ && tarcmd || deldb
      else
        pass $@
        echo -e "Database not saved yet! Save it by \"$PROGRAM_ABS close\"."
      fi
    ;;
esac
