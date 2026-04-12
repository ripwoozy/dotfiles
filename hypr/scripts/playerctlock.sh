#!/usr/bin/env bash

WIDTH=30
COVER_DIR="/tmp/polybar_cover"
COVER_FILE="$COVER_DIR/cover.jpg"

print_usage() {
  printf "Usage: %s --title | --arturl | --artist | --length | --album | --source | --status\n" "$0"
}

# ---------- helpers ----------------------------------------------------------
meta() { playerctl metadata --format "{{ ${1} }}" 2>/dev/null; }

escape_markup() {
  local s=${1//&/&amp;}
  s=${s//</&lt;}
  s=${s//>/&gt;}
  printf "%s" "$s"
}

ellipsis() {                     # truncate & add …
  local esc=$(escape_markup "$1")
  local len=${#esc}
  if (( len > WIDTH )); then
    printf "%s…" "${esc:0:$((WIDTH-1))}"
  else
    printf "%s" "$esc"
  fi
}

format_mmss() { printf "%02d:%02d" $(( $1/60 )) $(( $1%60 )); }

length_elapsed_total() {
  local total_us="$1"
  [[ -z $total_us ]] && return
  local total_sec=$(( total_us / 1000000 ))

  local pos
  pos=$(playerctl position 2>/dev/null) || return
  local pos_sec=${pos%.*}
  (( pos_sec < 0 || pos_sec > total_sec )) && pos_sec=0

  printf "%s/%s" "$(format_mmss "$pos_sec")" "$(format_mmss "$total_sec")"
}

cache_cover() {
  local url="$1"
  [[ -z $url ]] && { printf ""; return; }

  if [[ $url == file://* ]]; then
    printf "%s" "${url#file://}"
    return
  fi

  mkdir -p "$COVER_DIR"
  local stamp="$COVER_DIR/url.txt"
  if [[ ! -f $COVER_FILE || $(<"$stamp") != "$url" ]]; then
    curl -sL --max-time 4 -o "$COVER_FILE" "$url" && echo "$url" > "$stamp"
  fi
  printf "%s" "$COVER_FILE"
}

source_icon() {
  case "$1" in
    *firefox*)  printf "Firefox 󰈹" ;;
    *spotify*)  printf "Spotify " ;;
    *chromium*) printf "Chrome " ;;
  esac
}

# ---------- main -------------------------------------------------------------
[[ $# -ne 1 ]] && { print_usage; exit 1; }

case "$1" in
  --title)
    title=$(meta "xesam:title")
    [[ -n $title ]] && ellipsis "$title"
    ;;
  --arturl)
    cache_cover "$(meta "mpris:artUrl")"
    ;;
  --artist)
    artist=$(meta "xesam:artist")
    [[ -n $artist ]] && ellipsis "$artist"
    ;;
  --length)
    length_elapsed_total "$(meta "mpris:length")"
    ;;
  --status)
    case "$(playerctl status 2>/dev/null)" in
      Playing) printf "󰎆" ;; Paused) printf "󱑽" ;;
    esac
    ;;
  --album)
    album=$(meta "xesam:album")
    if [[ -n $album ]]; then
      ellipsis "$album"
    elif playerctl status &>/dev/null; then
      printf "No album"
    fi
    ;;
  --source)
    source_icon "$(meta "mpris:trackid")"
    ;;
  *)
    print_usage; exit 1 ;;
esac
