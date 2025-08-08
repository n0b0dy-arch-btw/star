#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
RESET='\033[0m'

# System-wide install path
INSTALL_PATH="/usr/local/bin/star"

# Check if running from system-wide install path
check_install() {
  if [[ "$(realpath "$0")" != "$INSTALL_PATH" ]]; then
    echo -e "${YELLOW}Star editor is not installed system-wide.${RESET}"
    read -rp "Do you want to install it system-wide to $INSTALL_PATH? (y/n): " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}You need to run this script as root or with sudo to install system-wide.${RESET}"
        exit 1
      fi
      cp "$0" "$INSTALL_PATH"
      chmod +x "$INSTALL_PATH"
      echo -e "${GREEN}Installed star to $INSTALL_PATH.${RESET}"
      echo -e "You can now run it from anywhere by typing ${CYAN}star${RESET}."
      exit 0
    else
      echo "Continuing without system-wide install."
      sleep 1
    fi
  fi
}

spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  while kill -0 "$pid" 2>/dev/null; do
    for i in $(seq 0 3); do
      printf "\r${CYAN}Loading ${spinstr:i:1}${RESET}"
      sleep $delay
    done
  done
  printf "\r${GREEN}Loaded!        ${RESET}\n"
}

print_logo() {
  echo -e "${YELLOW}       *       "
  echo -e "      / \\      "
  echo -e "  *--*---*--*  "
  echo -e "      \\ /      "
  echo -e "       *       ${RESET}"
  echo
  echo -e "${MAGENTA}Simple Command Mode Editor - 'star'${RESET}"
  echo
}

FILE="${1:-star}"

load_file() {
  if [[ ! -f "$1" ]]; then
    echo -e "${RED}File '$1' does not exist, creating new.${RESET}"
    sleep 1
    touch "$1"
  fi
  mapfile -t lines < "$1"
  FILE="$1"
  dirty=0
}

clear_buffer() {
  lines=()
  dirty=0
}

list_files() {
  echo -e "${CYAN}Text files in current directory:${RESET}"
  shopt -s nullglob
  files=(*.txt *.md *.log *.csv *.json)
  if [ ${#files[@]} -eq 0 ]; then
    echo "  No text files found."
  else
    for f in "${files[@]}"; do
      echo "  $f"
    done
  fi
  read -rsp $'Press any key to continue...\n' -n1
}

dirty=0
lines=()

# Run install check at start
check_install

# Loading spinner simulation
{
  sleep 2
} & spinner $!

load_file "$FILE"

print_lines() {
  clear
  print_logo
  echo -e "${CYAN}File:${RESET} $FILE"
  echo "-------------------------"
  for i in "${!lines[@]}"; do
    printf "${YELLOW}%3d:${RESET} %s\n" $((i+1)) "${lines[i]}"
  done
  echo "-------------------------"
  echo -e "${GREEN}Type lines to add/edit.${RESET}"
  echo -e "${GREEN}Commands start with '-':${RESET}"
  echo -e "  ${CYAN}-e [num]${RESET}        edit line"
  echo -e "  ${CYAN}-d [num]${RESET}        delete line"
  echo -e "  ${CYAN}-a${RESET}              append new line"
  echo -e "  ${CYAN}-s${RESET}              save file"
  echo -e "  ${CYAN}-saveas${RESET}          save file as new path"
  echo -e "  ${CYAN}-open [filename]${RESET} open file"
  echo -e "  ${CYAN}-close${RESET}           close current file (clear buffer)"
  echo -e "  ${CYAN}-list${RESET}            list text files in current directory"
  echo -e "  ${CYAN}-q${RESET}              quit editor"
  echo
}

edit_line() {
  local lineno=$1
  if ! [[ "$lineno" =~ ^[0-9]+$ ]] || (( lineno < 1 || lineno > ${#lines[@]} )); then
    echo -e "${RED}Invalid line number${RESET}"
    read -rsp $'Press any key...\n' -n1
    return
  fi
  echo -e "${YELLOW}Current line $lineno:${RESET} ${lines[$((lineno-1))]}"
  read -rp "New content: " newcontent
  lines[$((lineno-1))]="$newcontent"
  dirty=1
}

delete_line() {
  local lineno=$1
  if ! [[ "$lineno" =~ ^[0-9]+$ ]] || (( lineno < 1 || lineno > ${#lines[@]} )); then
    echo -e "${RED}Invalid line number${RESET}"
    read -rsp $'Press any key...\n' -n1
    return
  fi
  unset 'lines[$((lineno-1))]'
  lines=("${lines[@]}")
  dirty=1
}

append_line() {
  read -rp "New line content: " newcontent
  lines+=("$newcontent")
  dirty=1
}

save_file() {
  read -rp "Save to current file '$FILE'? (y/n): " yn
  if [[ "$yn" =~ ^[Nn]$ ]]; then
    save_as_file
    return
  fi

  printf "%s\n" "${lines[@]}" > "$FILE"
  dirty=0
  echo -e "${GREEN}File saved to $FILE.${RESET}"
  read -rsp $'Press any key...\n' -n1
}

save_as_file() {
  read -rp "Enter directory to save in (default: current dir): " dir
  if [[ -z "$dir" ]]; then
    dir="."
  fi

  if [[ ! -d "$dir" ]]; then
    echo -e "${RED}Directory does not exist.${RESET}"
    read -rsp $'Press any key...\n' -n1
    return
  fi

  read -rp "Enter filename: " filename
  if [[ -z "$filename" ]]; then
    echo -e "${RED}Filename cannot be empty.${RESET}"
    read -rsp $'Press any key...\n' -n1
    return
  fi

  local fullpath="$dir/$filename"
  printf "%s\n" "${lines[@]}" > "$fullpath"
  FILE="$fullpath"
  dirty=0
  echo -e "${GREEN}File saved to $fullpath.${RESET}"
  read -rsp $'Press any key...\n' -n1
}

open_file() {
  local filename="$1"
  if [[ -z "$filename" ]]; then
    echo -e "${RED}No filename provided to open.${RESET}"
    read -rsp $'Press any key...\n' -n1
    return
  fi

  if (( dirty )); then
    read -rp "Unsaved changes! Save before opening new file? (y/n): " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      save_file
    fi
  fi

  if [[ ! -f "$filename" ]]; then
    echo -e "${RED}File '$filename' does not exist. Create new? (y/n):${RESET} "
    read -r create
    if [[ "$create" =~ ^[Yy]$ ]]; then
      touch "$filename"
    else
      echo "Open cancelled."
      read -rsp $'Press any key...\n' -n1
      return
    fi
  fi

  load_file "$filename"
}

close_file() {
  if (( dirty )); then
    read -rp "Unsaved changes! Save before closing? (y/n): " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      save_file
    fi
  fi

  clear_buffer
  FILE="(no file)"
}

print_lines

while true; do
  read -rp "Type text or command (-): " input

  if [[ "$input" == -* ]]; then
    cmd=$(echo "$input" | awk '{print $1}')
    arg=$(echo "$input" | cut -d' ' -f2-)
    case "$cmd" in
      -e)
        edit_line "$arg"
        ;;
      -d)
        delete_line "$arg"
        ;;
      -a)
        append_line
        ;;
      -s)
        save_file
        ;;
      -saveas)
        save_as_file
        ;;
      -open)
        open_file "$arg"
        ;;
      -close)
        close_file
        ;;
      -list)
        list_files
        ;;
      -q)
        if (( dirty )); then
          read -rp "Unsaved changes! Save before quit? (y/n): " yn
          if [[ "$yn" =~ ^[Yy]$ ]]; then
            save_file
          fi
        fi
        break
        ;;
      *)
        echo -e "${RED}Unknown command.${RESET}"
        read -rsp $'Press any key...\n' -n1
        ;;
    esac
  else
    lines+=("$input")
    dirty=1
  fi

  print_lines
done

clear
echo -e "${MAGENTA}Exited editor. Bye!${RESET}"
