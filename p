#!/bin/bash

# Wrapper for pass by Trepet
# © GPLv3

# Path to the app, do not edit, use $SCR below to make program portable !experimental!
SCR="$( cd "$(dirname "$0")" ; pwd -P )"

# GPG keys and config homedir, e.g. "$HOME/.gnupg"
GNUPGHOME="$HOME/.gnupg"

# Path to encrypted database, will be created if not exists
# It MUST end with .tar.gpg extension
ENCRYPTED_FILENAME="$HOME/pass/db.tar.gpg"

# GPG encryption key(s)
PASSWORD_STORE_KEY='0xXXXXXXXX'

# Options to password generation, check pass help
GENOPTS='--no-symbols'

# Password length when generating
GENLEN='28'

# Path to editor apps
EDITOR_X='gedit'
EDITOR_CONSOLE='nano'

# Uncomment to use experimental minimal zenity editor
EDITOR_X="zenity_editor"

# apps defaults

rofi_cmd () {
rofi -dmenu -i -bg \#222222 -fg \#ffffff -hlbg \#222222 -hlfg \#11dd11 -opacity 90 -lines 15 -width -40 -font "mono 16" -no-levenshtein-sort -disable-history -p pass: -mesg "$rofi_mesg"
}

dmenu_cmd () {
dmenu -l 20 -b -nb \#222222 -nf \#ffffff -sb \#222222 -sf \#11dd11 $@
}

zenity_size="--width=600 --height=400"

# Terminal emulator, not usable yet
# TERMEMU='sakura -x'

# You usually don't need to edit anything below this line #
###########################################################
TMPDIR='/dev/shm'
PASS_HOME_REALBASENAME="$(basename $ENCRYPTED_FILENAME)"
PASS_HOME_BASENAME="${PASS_HOME_REALBASENAME%.tar.gpg}"
PASS_HOME_DIRNAME="$(dirname $ENCRYPTED_FILENAME)"
PASS_HOME_UNPACKED="$TMPDIR/$PASS_HOME_BASENAME"
DATE="$(date +%Y-%m-%d-%Hh)"
PROGRAM="${0##*/}"
PROGRAM_ABS="$SCR/$PROGRAM"
BACKUPDIR="$PASS_HOME_DIRNAME"
[[ -n $DISPLAY && $XDG_VTNR -eq 1 ]] && INX=yes
[[ -n $INX && $(command -v zenity) ]] && ZENEX=yes

[[ -n $INX ]] && export EDITOR="$EDITOR_X" || export EDITOR="$EDITOR_CONSOLE"

rofi_default_mesg='<b>Copy pass to clipboard</b>'
rofi_show_mesg='<b>Show password</b>'
rofi_type_mesg='<b>Type password</b>'
rofi_edit_mesg='<b>Edit password</b>'
rofi_del_mesg='<b>Delete password</b>'

usage() {
  cat <<EOF

password-store wrapper by Trepet

usage: $PROGRAM [action]

  action:
    backup, b - backup existing encrypted database
    open, o - decrypt database and extract it to $PASS_HOME_UNPACKED
    close, c - encrypt database at $PASS_HOME_UNPACKED and save it to $ENCRYPTED_FILENAME
    dmenu, d - use dmenu to list, choose password and copy it to clipboard
    rofi, r - use rofi to list, choose password and copy it to clipboard
    gen, g - generate pass of $GENLEN characters using zenity as prompt for new entry

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

if [[ $1 = @(-h|--help|-?) ]]; then
  usage
  exit $(( $# ? 0 : 1 ))
fi

die() {
  if [[ -n $ZENEX ]]; then
    zenity --error --no-markup --text "$@"
    exit 1
  else
    echo "$@" >&2
    exit 1
  fi
}

zenity_editor () {
  local pass_tmpf="$@"
  local new_pass=$(zenity --text-info --editable --width=600 --height=400 --filename="$pass_tmpf" || echo pass_wrapper_zenity_editor_cancel) # :)
  [[ $new_pass != 'pass_wrapper_zenity_editor_cancel' ]] && echo -e "$new_pass" > "$pass_tmpf"
}

export -f zenity_editor

backup () {
  if [[ -f "$ENCRYPTED_FILENAME" ]]; then
    cp "$ENCRYPTED_FILENAME" "$BACKUPDIR"/"${PASS_HOME_BASENAME}_$DATE.tar.gpg" || die "Error"
  else
    die "Encrypted database does not exist, run \"$PROGRAM_ABS encdb\" command fisrt"
  fi
}

tarcmd () {
  if [[ -d "$PASS_HOME_UNPACKED" ]]; then
    tar --preserve-permissions -C "$TMPDIR" --remove-files -c "$PASS_HOME_BASENAME" | \
    gpg --encrypt -r "$PASSWORD_STORE_KEY" > "$ENCRYPTED_FILENAME" || die "Error"
  else
    die "Unpacked dir does not exist"
  fi
}

untarcmd () {
  if [[ -f "$ENCRYPTED_FILENAME" ]]; then
    gpg -d "$ENCRYPTED_FILENAME" | tar -x --preserve-permissions -C "$TMPDIR"/ || die "Error"
  else
    die "Encrypted database does not exist"
  fi
}

deldb () {
  rm -rf "$PASS_HOME_UNPACKED"
  echo "No changes made"
}

newdb () {
  NEWDIR=${ENCRYPTED_FILENAME%.tar.gpg}
  [[ ! -d "$NEWDIR" ]] && mkdir -p "$NEWDIR" || die "$NEWDIR folder exists"
  echo "$PASSWORD_STORE_KEY" > "$NEWDIR/.gpg-id"
  chmod -R go-rwx "$NEWDIR" && \
  tar --preserve-permissions -C "$PASS_HOME_DIRNAME" -c "$(basename $NEWDIR)" | \
  gpg --encrypt -r "$PASSWORD_STORE_KEY" > "$ENCRYPTED_FILENAME" || die "Error"
  rm --recursive "$NEWDIR" && \
  echo "$ENCRYPTED_FILENAME created. You should add some passwords now"
}

case $1 in

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
    newentry=$(zenity  --title "New password" --entry --text="No spaces in names") || exit 1
    [[ -n $newentry ]] && "$PROGRAM_ABS" generate "$GENOPTS" "$newentry" $GENLEN &>/dev/null
    notify-send pass "Pass of $GENLEN length generated: $newentry" -h string:sound-name:message-new-email
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
      notify-send pass "Password $password deleted"
    fi
  ;;

  *)
    if [[ -f $ENCRYPTED_FILENAME ]]; then
      export PASSWORD_STORE_DIR="$PASS_HOME_UNPACKED"
      if [[ ! -d "$PASS_HOME_UNPACKED" ]]; then
        untarcmd
        pass $@ && tarcmd || deldb
      else
        pass $@
        echo -e "Database not saved yet! Save it by \"$PROGRAM_ABS close\"."
      fi
    else
      newdb
    fi
  ;;
esac
