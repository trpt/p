#!/bin/bash

# pass wrapper by Trepet
# v. 2.0
# © GPLv3

# Path to the app, do not edit, use $SCR below to make program portable !experimental!
SCR="$( cd "$(dirname "$0")" ; pwd -P )"

# GPG keys and config homedir, e.g. "$HOME/.gnupg"
GNUPGHOME="$HOME/.gnupg"

# Path to encrypted database, will be created if not exists
# It MUST end with .tar.gpg extension
ENCRYPTED_FILENAME="$HOME/pass/db.tar.gpg"

# GPG encryption key(s)
PASSWORD_STORE_KEY='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'

# Options to password generation, check pass help
GENOPTS='--no-symbols'

# Password length when generating
GENLEN='28'

# Path to editor apps
EDITOR_X='gedit'
EDITOR_CONSOLE='nano'

# Uncomment to use minimal zenity editor
EDITOR_X="zenity_editor"

# Explicit choice of language, 'ru' and 'en' supported
#lang='ru'

### Apps defaults

# Explicit choice of dmenu or rofi for key selection
#menu='dmenu'
#menu='rofi'

rofi_cmd () {
  rofi -dmenu -i -color-window "#232832, #232832, #404552" -color-normal "#232832, #dddddd, #232832, #232832, #00CCFF" -color-active "#232832, #00b1ff, #232832, #232832, #00b1ff" -color-urgent "#232832, #ff1844, #232832, #232832, #ff1844" -opacity 90 -lines 15 -width -40 -font "mono 16" -no-levenshtein-sort -disable-history -p pass: -mesg "$rofi_mesg"
}

dmenu_cmd () {
  dmenu -l 20 -b -nb \#222222 -nf \#ffffff -sb \#222222 -sf \#11dd11 $@
}

zenity_size="--width=600 --height=400"
zenity_ask_size="--height=300 "

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
[[ -n $DISPLAY ]] && INX=yes
[[ -n $INX && $(command -v zenity) ]] && ZENEX=yes

if [[ $custom_editor = 'yes' ]]; then
  [[ -n $INX ]] && export EDITOR="$editor_x" || export EDITOR="$editor_console"
fi

translate() {
  [[ -z $lang ]] && lang=${LANG:0:2}

  declare -A tr_en=([title]='pass wrapper' [rofi_default_mesg]='<b>Copy pass to clipboard</b>' [rofi_show_mesg]='<b>Show password</b>' [rofi_type_mesg]='<b>Type password</b>' [rofi_edit_mesg]='<b>Edit password</b>' [rofi_del_mesg]='<b>Delete password</b>' [no_display]='No DISPLAY found' [zenity_req]='Zenity is required to run this command' [d_r_req]='dmenu or rofi is required to run this command' [bck_fail]="Encrypted database does not exist, run this command first:" [unp_dir_fail]='Unpacked dir does not exist' [enc_db_fail]='Encrypted database does not exist' [no_changes]='No changes made' [error]='Error' [newdir_fail]="Folder exists:" [newdb_created]="created. You should add some passwords now" [what_todo]='What to do?' [choose]='Choose' [action]="Action" [type]='Type' [show]='Show' [edit]='Edit' [add]='Add' [delete]='Delete' [bck_created]="created" [new_password]='New password' [no_spaces]='No spaces in names' [pass_generated]="Pass of $GENLEN length generated:" [del_pass_msg]='You are about to unrecoverably remove password entry!' [xdt_xte_req]='xte or xdotool needed' [pass_deleted]="deleted" [db_unencrypted]='Database is unencrypted! Save it by')

  declare -A tr_ru=([title]='Оболочка pass' [rofi_default_mesg]='<b>Скопировать пароль в буфер</b>' [rofi_show_mesg]='<b>Показать пароль</b>' [rofi_type_mesg]='<b>Напечатать пароль</b>' [rofi_edit_mesg]='<b>Редактировать пароль</b>' [rofi_del_mesg]='<b>Удалить пароль</b>' [no_display]='Переменная DISPLAY не задана' [zenity_req]='Для этой команды нужна программа Zenity' [d_r_req]='Для этой команды нужна программа dmenu или rofi' [bck_fail]="Шифрованная БД еще не создана, запустите сначала команду" [unp_dir_fail]='Распакованной директории не существует' [enc_db_fail]='Шифрованной БД не существует' [no_changes]='Изменений не было' [error]='Ошибка' [newdir_fail]="Директория существует:" [newdb_created]="создан. Теперь можно добавлять пароли" [what_todo]='Что нужно сделать?' [choose]='Выбор' [action]="Действие" [type]='Напечатать' [show]='Показать' [edit]='Редактировать' [add]='Добавить' [delete]='Удалить' [bck_created]="создан" [new_password]='Новый пароль' [no_spaces]='Без пробелов в именах' [pass_generated]="Пароль длиной $GENLEN сгенерирован:" [del_pass_msg]='Вы собираетесь безвозвратно удалить запись с паролем!' [xdt_xte_req]='Нужна программа xte или xdotool' [pass_deleted]="удален" [db_unencrypted]='БД расшифрована! Сохраните ее командой')

  case $lang in
  ru)
    [[ -z ${tr_ru[$1]} ]] && echo "${tr_en[$1]}" || echo "${tr_ru[$1]}"
  ;;
  *)
    echo "${tr_en[$1]}"
  ;;
  esac
}

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
    menu - show menu for action

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

check_x() {
  [[ $INX = 'yes' ]] || die "$(translate no_display)"
  [[ $ZENEX != 'yes' && $check_zenity = 'yes' ]] && die "$(translate zenity_req)"
  [[ $(command -v rofi) || $(command -v dmenu) ]] || die "$(translate d_r_req)"
  if [[ -z $menu ]]; then
    [[ ($(command -v dmenu)) ]] && menu='dmenu'
    [[ ($(command -v rofi)) ]] && menu='rofi'
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
    cp "$ENCRYPTED_FILENAME" "$BACKUPDIR"/"${PASS_HOME_BASENAME}_$DATE.tar.gpg" || die "$(translate error)"
  else
    die "$(translate bck_fail) \"$PROGRAM_ABS\""
  fi
}

tarcmd () {
  if [[ -d "$PASS_HOME_UNPACKED" ]]; then
    tar --preserve-permissions -C "$TMPDIR" --remove-files -c "$PASS_HOME_BASENAME" | \
    gpg --encrypt -r "$PASSWORD_STORE_KEY" > "$ENCRYPTED_FILENAME" || die "$(translate error)"
  else
    die "$(translate unp_dir_fail)"
  fi
}

untarcmd () {
  if [[ -f "$ENCRYPTED_FILENAME" ]]; then
    gpg -d "$ENCRYPTED_FILENAME" | tar -x --preserve-permissions -C "$TMPDIR"/ || die "$(translate error)"
  else
    die "$(translate enc_db_fail)"
  fi
}

deldb () {
  rm -rf "$PASS_HOME_UNPACKED"
  echo "$(translate no_changes)"
}

newdb () {
  NEWDIR=${ENCRYPTED_FILENAME%.tar.gpg}
  [[ ! -d "$NEWDIR" ]] && mkdir -p "$NEWDIR" || die "$(translate newdir_fail) $NEWDIR"
  echo "$PASSWORD_STORE_KEY" > "$NEWDIR/.gpg-id"
  chmod -R go-rwx "$NEWDIR" && \
  tar --preserve-permissions -C "$PASS_HOME_DIRNAME" -c "$(basename $NEWDIR)" | \
  gpg --encrypt -r "$PASSWORD_STORE_KEY" > "$ENCRYPTED_FILENAME" || die "$(translate error)"
  rm --recursive "$NEWDIR" && \
  echo "$ENCRYPTED_FILENAME $(translate newdb_created)"
}

if [[ $1 = 'menu' ]]; then
  check_zenity='yes' check_x

  ask=$(zenity $zenity_ask_size --list  --hide-header --text="$(translate what_todo)" --title "$(translate title)" --radiolist  --column "$(translate choose)" --column "$(translate action)" TRUE "$(translate type)" FALSE "$(translate show)" FALSE "$(translate add)" FALSE "$(translate edit)" FALSE "$(translate delete)")

  case $ask in
  "$(translate type)")
    set $menu --type
  ;;

  "$(translate show)")
    set $menu --show
  ;;

  "$(translate add)")
    set gen
  ;;

  "$(translate edit)")
    set $menu --edit
  ;;

  "$(translate delete)")
    set $menu --del
  ;;

  *)
    exit 0
  ;;
  esac
fi

case $1 in

  backup | b)
    backup && \
    echo -e " $BACKUPDIR/${PASS_HOME_BASENAME}_$DATE.tar.gpg $(translate bck_created)"
  ;;

  open | o)
    untarcmd
  ;;

  close | c)
    tarcmd
  ;;

  gen | g)
    check_zenity='yes' check_x
    newentry=$(zenity  --title "$(translate new_password)" --entry --text="$(translate no_spaces)") || exit 1
    [[ -n $newentry ]] && "$PROGRAM_ABS" generate "$GENOPTS" "$newentry" $GENLEN &>/dev/null
    notify-send pass "$(translate pass_generated) $newentry" -h string:sound-name:message-new-email --icon=document-new
  ;;

  rofi | dmenu | r | d)
    check_x
    if [[ $1 == "rofi" || $1 == "r" ]]; then
      menu="rofi_cmd"
      rofi_mesg=$(translate rofi_default_mesg)
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
      [[ $menu == rofi_cmd ]] && rofi_mesg="$(translate rofi_type_mesg)"
      shift
    fi

    if [[ $1 == "--show" || $1 == "-s" || $1 == "s" ]]; then
      showit=1
      [[ $menu == rofi_cmd ]] && rofi_mesg="$(translate rofi_show_mesg)"
      shift
    fi

    if [[ $1 == "--edit" || $1 == "-e" || $1 == "e" ]]; then
      editit=1
      [[ $menu == rofi_cmd ]] && rofi_mesg="$(translate rofi_edit_mesg)"
      shift
    fi

    if [[ $1 == "--del" || $1 == "-d" || $1 == "d" ]]; then
      notify-send pass "$(translate del_pass_msg)" -h string:sound-name:message-new-email --icon=edit-clear
      delit=1
      [[ $menu == rofi_cmd ]] && rofi_mesg="$(translate rofi_del_mesg)"
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
      typepass=$("$PROGRAM_ABS" show "$password" | awk 'BEGIN{ORS=""} {print; exit}')
      [[ ($(command -v xte)) ]] && xte "str $typepass" || \
      ([[ ($(command -v xdotool)) ]] && xdotool type --clearmodifiers "$typepass" || die "$(translate xdt_xte_req)")
      unset typepass
    elif [[ $showit -eq 1 ]]; then
      check_zenity='yes' check_x
      "$PROGRAM_ABS" show "$password" | zenity $zenity_size --text-info --title="$password"
    elif [[ $editit -eq 1 ]]; then
      "$PROGRAM_ABS" edit "$password"
    elif [[ $delit -eq 1 ]]; then
      "$PROGRAM_ABS" rm -f "$password" &>/dev/null
      notify-send pass "$password $(translate pass_deleted)" --icon=edit-delete
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
        echo -e "$(translate db_unencrypted) \"$PROGRAM_ABS close\"."
      fi
    else
      newdb
    fi
  ;;
esac

