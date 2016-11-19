#!/bin/bash

# pass wrapper by Trepet
# v. 2.8.1
# © GPLv3

# Path to the app, do not edit ##########
SCR="$( cd "$(dirname "$0")" ; pwd -P )"
PROGRAM="${0##*/}"
PROGRAM_ABS="$SCR/$PROGRAM"
#########################################

# GPG keys and config homedir
GNUPGHOME="$HOME/.gnupg"

# GPG encryption key(s)
PASSWORD_STORE_KEY='XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'

# Database name
dbname='db'

# Database and backup storage directory. It will be created if not exists
dbdir="$HOME/.pass"

# Options to password generation, check pass help
genopts='--no-symbols'

# Password length when generating
genlen='28'

# Path to editor apps
custom_editor='yes'
editor_x='gedit'
editor_console='nano'

# Use minimal zenity editor instead of usual
editor_x="zenity_editor"

# Make auto-backup on every action if last backup was N days ago
# Set to 0 to disable auto-backup feature
auto_backup=7

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
zenity_ask_size="--height=340 "

# You usually don't need to edit anything below this line #
###########################################################

# Dir to unpack database. It SHOULD be in RAM
tmpdir='/dev/shm'

# Delete trailing slashes in dbdir
dbdir=$(echo "$dbdir" | sed 's:/*$::')

# Auto-backup depends on this format
curdate="$(date +%Y-%m-%d-%Hh)"

encrypted_filename="$dbname.tar.gpg"
encrypted_fullpath="$dbdir/$encrypted_filename"
pass_home_unpacked="$tmpdir/$dbname"
backupdir="$dbdir"
lockfile="$tmpdir/.$dbname-passlock"
[[ -n $DISPLAY ]] && in_x='yes'
[[ -n $in_x && $(command -v zenity) ]] && zen_x=yes

if [[ $custom_editor = 'yes' ]]; then
  [[ -n $in_x ]] && export EDITOR="$editor_x" || export EDITOR="$editor_console"
fi

translate() {
  [[ -z $lang ]] && lang=${LANG:0:2}

  declare -A tr_en=([title]='pass wrapper' [pass_running]='pass is running, please wait...' [rofi_default_mesg]='<b>Copy pass to clipboard</b>' [rofi_show_mesg]='<b>Show password</b>' [rofi_type_mesg]='<b>Type password</b>' [rofi_edit_mesg]='<b>Edit password</b>' [rofi_del_mesg]='<b>Delete password</b>' [no_display]='No DISPLAY found' [pass_req]='password-store required to run this app' [zenity_req]='Zenity is required to run this command' [d_r_req]='dmenu or rofi is required to run this command' [bck_fail]="Encrypted database does not exist, run this command first:" [unp_dir_fail]='Unpacked dir does not exist' [enc_db_fail]='Encrypted database does not exist' [no_changes]='No changes made' [error]='Error' [newdir_fail]="Folder exists:" [newdb_created]="created. You should add some passwords now" [what_todo]='What to do?' [choose]='Choose' [action]="Action" [type]='Type' [show]='Show' [edit]='Edit' [add]='Add' [delete]='Delete' [make_bck]="Backup" [bck_created]="created" [new_password]='New password' [no_spaces]='No spaces in names' [pass_generated]="Pass of $genlen length generated:" [del_pass_msg]='You are about to unrecoverably remove password entry!' [xdt_xte_req]='xte or xdotool needed' [pass_deleted]="deleted" [db_unencrypted]='Database is unencrypted! Save it by' [lock_error]="Complete all previous operations or remove file $lockfile" [newentry_exist]='Entry already exists' [search]='Search' [search_password]='Search password' [search_entry]='Search entry' [search_result]='Search result')

  declare -A tr_ru=([title]='Оболочка pass' [pass_running]='pass работает, ждите...' [rofi_default_mesg]='<b>Скопировать пароль в буфер</b>' [rofi_show_mesg]='<b>Показать пароль</b>' [rofi_type_mesg]='<b>Напечатать пароль</b>' [rofi_edit_mesg]='<b>Редактировать пароль</b>' [rofi_del_mesg]='<b>Удалить пароль</b>' [no_display]='Переменная DISPLAY не задана' [pass_req]='Необходима программа password-store' [zenity_req]='Для этой команды нужна программа Zenity' [d_r_req]='Для этой команды нужна программа dmenu или rofi' [bck_fail]="Шифрованная БД еще не создана, запустите сначала команду" [unp_dir_fail]='Распакованной директории не существует' [enc_db_fail]='Шифрованной БД не существует' [no_changes]='Изменений не было' [error]='Ошибка' [newdir_fail]="Директория существует:" [newdb_created]="создан. Теперь можно добавлять пароли" [what_todo]='Что нужно сделать?' [choose]='Выбор' [action]="Действие" [type]='Напечатать' [show]='Показать' [edit]='Редактировать' [add]='Добавить' [delete]='Удалить' [make_bck]="Резервная копия" [bck_created]="создан" [new_password]='Новый пароль' [no_spaces]='Без пробелов в именах' [pass_generated]="Пароль длиной $genlen сгенерирован:" [del_pass_msg]='Вы собираетесь безвозвратно удалить запись с паролем!' [xdt_xte_req]='Нужна программа xte или xdotool' [pass_deleted]="удален" [db_unencrypted]='БД расшифрована! Сохраните ее командой' [lock_error]="Закончите все текущие операции с БД или удалите файл $lockfile" [newentry_exist]='Такая запись уже существует' [search]='Поиск' [search_password]='Поиск пароля' [search_entry]='Строка поиска' [search_result]='Результат поиска')

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
    open, o - decrypt database and extract it to $pass_home_unpacked
    close, c - encrypt database at $pass_home_unpacked and save it to $encrypted_fullpath
    dmenu, d - use dmenu to list, choose password and copy it to clipboard
    rofi, r - use rofi to list, choose password and copy it to clipboard
    gen, g - generate pass of $genlen characters using zenity as prompt for new entry
    zensearch, zs - use pass' grep command and display result with zenity
    menu - show zenity menu for action

  Other commands go to pass directly

  dmenu or rofi action parameters:
    --type, -t, t - use xte or xdotool to autotype password
    --show, -s, s - use zenity to show content
    --edit, -e, e - edit chosen entry with $EDITOR
    --del,  -d, d - delete entry

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
    $encrypted_fullpath

    editor:
    $EDITOR
EOF
}

if [[ $1 = @(-h|--help|-?) ]]; then
  usage
  exit $(( $# ? 0 : 1 ))
fi

zen_progress() { tee >(zenity --progress --auto-close --no-cancel --title="$(translate title)" --text "$(translate pass_running)" --pulsate) >&1 ;}

die() {
  if [[ -n $zen_x ]]; then
    zenity --error --no-markup --no-wrap --text "$@"
    exit 1
  else
    echo "$@" >&2
    exit 1
  fi
}

[[ $(command -v pass) || $(command -v password-store) ]] || die "$(translate pass_req)"

check_x() {
  [[ $in_x = 'yes' ]] || die "$(translate no_display)"
  [[ $zen_x != 'yes' && $check_zenity = 'yes' ]] && die "$(translate zenity_req)"
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
  if [[ -f "$encrypted_fullpath" ]]; then
    cp "$encrypted_fullpath" "$backupdir"/"${dbname}_$curdate.tar.gpg" || die "$(translate error)"
  else
    die "$(translate bck_fail) \"$PROGRAM_ABS\""
  fi
}

autobackup () {
  if (( $auto_backup > 0 )); then
    local findbck=$(find "$backupdir" -maxdepth 1 -mtime -"${auto_backup}" -name "${dbname}_*h.tar.gpg" -type f)
    [[ -z $findbck ]] && backup
  fi
}

tarcmd () {
  if [[ -d "$pass_home_unpacked" ]]; then
    tar --preserve-permissions -C "$tmpdir" --remove-files -c "$dbname" | \
    gpg --encrypt -r "$PASSWORD_STORE_KEY" > "$encrypted_fullpath" || die "$(translate error)"
    rm "$lockfile"
  else
    die "$(translate unp_dir_fail)"
  fi
}

untarcmd () {
  [[ -f "$lockfile" ]] && die "$(translate lock_error)"

  if [[ -f "$encrypted_fullpath" ]]; then
    gpg -d "$encrypted_fullpath" | tar -x --preserve-permissions -C "$tmpdir"/ || die "$(translate error)"
    touch "$lockfile"
  else
    die "$(translate enc_db_fail)"
  fi
}

no_changes () {
  rm -rf "$pass_home_unpacked"
  [[ -f "$lockfile" ]] && rm "$lockfile"
  [[ -n $in_x ]] && notify-send pass "$(translate no_changes)" --icon=dialog-information \
    || echo "$(translate no_changes)"
}

newdb () {
  newdir="$dbdir/$dbname"
  [[ ! -d "$newdir" ]] && mkdir --mode=0700 --parents "$newdir" || die "$(translate newdir_fail) $newdir"
  echo "$PASSWORD_STORE_KEY" > "$newdir/.gpg-id" && \
  tar --preserve-permissions --directory="$dbdir" --create "$dbname" | \
  gpg --encrypt --recipient "$PASSWORD_STORE_KEY" > "$encrypted_fullpath" || die "$(translate error)"
  rm --recursive "$newdir" && \
  echo "$encrypted_fullpath $(translate newdb_created)" && \
  notify-send pass "$encrypted_fullpath $(translate newdb_created)" --icon=dialog-information
}

if [[ $1 = 'menu' ]]; then
  check_zenity='yes' check_x

  ask=$(zenity $zenity_ask_size --list  --hide-header --text="$(translate what_todo)" --title "$(translate title)" --radiolist  --column "$(translate choose)" --column "$(translate action)" TRUE "$(translate type)" FALSE "$(translate show)" FALSE "$(translate add)" FALSE "$(translate edit)" FALSE "$(translate delete)" FALSE "$(translate make_bck)" FALSE "$(translate search)")

  case $ask in
  "$(translate type)")
    set $menu --type ;;

  "$(translate show)")
    set $menu --show ;;

  "$(translate add)")
    set gen ;;

  "$(translate edit)")
    set $menu --edit ;;

  "$(translate delete)")
    set $menu --del ;;

  "$(translate make_bck)")
    backup && \
    notify-send pass "$backupdir/${dbname}_$curdate.tar.gpg $(translate bck_created)" --icon=dialog-information ; exit 0 ;;

  "$(translate search)")
    set zensearch ;;

  *)
    exit 0 ;;
  esac
fi

case $1 in

  backup | b)
    backup && \
    echo -e " $backupdir/${dbname}_$curdate.tar.gpg $(translate bck_created)" ;;

  open | o)
    untarcmd ;;

  close | c)
    tarcmd ;;

  gen | g)
    check_zenity='yes' check_x
    newentry=$(zenity --title "$(translate new_password)" --entry --text="$(translate no_spaces)") || exit 1
    newentry_fullpath="$tmpdir/$dbname/$newentry.gpg"
    untarcmd && { [[ -f "$newentry_fullpath" ]] && new_exist='yes' ; tarcmd ;} || exit 1
    [[ $new_exist == "yes" ]] && { unset $newentry && die "$(translate newentry_exist)" ;}
    [[ -n $newentry ]] && "$PROGRAM_ABS" generate "$genopts" "$newentry" $genlen &>/dev/null
    notify-send pass "$(translate pass_generated) $newentry" -h string:sound-name:message-new-email --icon=document-new
  ;;
  zensearch | zs)
    check_zenity='yes' check_x
    search_entry=$(zenity --title "$(translate search_password)" --entry --text="$(translate search_entry)") || exit 1
    search_output=$("$PROGRAM_ABS" grep "$search_entry" | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g" | zen_progress)
    zenity --info --no-markup --no-wrap --title="$(translate search_result)" --text="$search_output"
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
    export PASSWORD_STORE_DIR="$pass_home_unpacked"
    shift

    case "$1" in
      --type | -t | t)
        action='typeit' ; [[ $menu == rofi_cmd ]] && rofi_mesg="$(translate rofi_type_mesg)" ; shift ;;

      --show | -s | s)
        action='showit' ; [[ $menu == rofi_cmd ]] && rofi_mesg="$(translate rofi_show_mesg)" ; shift ;;

      --edit | -e | e)
        action='editit' ; [[ $menu == rofi_cmd ]] && rofi_mesg="$(translate rofi_edit_mesg)" ; shift ;;

      --del | -d | d)
        action='delit' ; notify-send pass "$(translate del_pass_msg)" -h string:sound-name:message-new-email --icon=edit-clear
        [[ $menu == rofi_cmd ]] && rofi_mesg="$(translate rofi_del_mesg)" ; shift ;;
    esac

    untarcmd && \
      { password_files=( "$PASSWORD_STORE_DIR"/**/*.gpg )
      password_files=( "${password_files[@]#$PASSWORD_STORE_DIR/}" )
      password_files=( "${password_files[@]%.gpg}" )
      password=$(printf '%s\n' "${password_files[@]}" | sort -f | $menu "$@")
      tarcmd; }

    [[ -n $password ]] || exit

    case "$action" in
      typeit)
        typepass=$("$PROGRAM_ABS" show "$password" | awk 'BEGIN{ORS=""} {print; exit}')
        [[ ($(command -v xte)) ]] && xte "str $typepass" || \
          { [[ ($(command -v xdotool)) ]] && xdotool type --clearmodifiers "$typepass" || die "$(translate xdt_xte_req)"; }
        unset typepass ;;

      showit)
        check_zenity='yes' check_x
        "$PROGRAM_ABS" show "$password" | zenity $zenity_size --text-info --title="$password" ;;

      editit)
        "$PROGRAM_ABS" edit "$password" ;;

      delit)
        "$PROGRAM_ABS" rm -f "$password" &>/dev/null
        notify-send pass "$password $(translate pass_deleted)" --icon=edit-delete ;;

      *)
        "$PROGRAM_ABS" show -c "$password" 2>/dev/null ;;
    esac
  ;;

  *)
    if [[ -f "$encrypted_fullpath" ]]; then
      export PASSWORD_STORE_DIR="$pass_home_unpacked"
      autobackup
      if [[ ! -d "$pass_home_unpacked" ]]; then
        untarcmd
        pass $@ && tarcmd || no_changes
      else
        pass $@
        [[ -n $in_x ]] && notify-send pass "$(translate db_unencrypted) \"$PROGRAM_ABS close\"" --icon=dialog-information \
          || echo -e "$(translate db_unencrypted) \"$PROGRAM_ABS close\""
      fi
    else
      newdb
    fi
  ;;
esac
