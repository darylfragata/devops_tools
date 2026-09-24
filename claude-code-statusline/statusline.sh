#!/usr/bin/env bash
# Claude Code status line: model | context bar | session cost | 5h / 7d plan usage (when reported)
input=$(cat)

model=$(jq -r '.model.display_name // "Claude"' <<<"$input")
ctx=$(jq -r '.context_window.used_percentage // empty' <<<"$input")
cost=$(jq -r '.cost.total_cost_usd // empty' <<<"$input")
dir=$(jq -r '.workspace.current_dir // .cwd // empty' <<<"$input")
sid=$(jq -r '.session_id // empty' <<<"$input")
dur=$(jq -r '.cost.total_duration_ms // empty' <<<"$input")
h5=$(jq -r '.rate_limits.five_hour.used_percentage // empty' <<<"$input")
d7=$(jq -r '.rate_limits.seven_day.used_percentage // empty' <<<"$input")
h5r=$(jq -r '.rate_limits.five_hour.resets_at // empty' <<<"$input")
d7r=$(jq -r '.rate_limits.seven_day.resets_at // empty' <<<"$input")

bar() { # pct -> 10-cell bar, coloured by level
  local p=${1%.*} n i out=""
  n=$(( p / 10 )); (( n > 10 )) && n=10
  local c=32; (( p >= 70 )) && c=33; (( p >= 90 )) && c=31
  for ((i = 0; i < 10; i++)); do (( i < n )) && out+="█" || out+="░"; done
  printf '\033[%sm%s\033[0m %s%%' "$c" "$out" "$p"
}

reset_in() { # epoch seconds or ISO string -> " ↻2h13m"; empty if unparseable/past
  local t=$1 s d
  [[ -z $t ]] && return
  [[ $t =~ ^[0-9]+$ ]] || t=$(date -d "$t" +%s 2>/dev/null) || return
  (( t > 20000000000 )) && t=$(( t / 1000 ))
  s=$(( t - $(date +%s) )); (( s <= 0 )) && return
  d=$(( s / 86400 ))
  if (( d > 0 )); then printf ' ↻%dd%dh' "$d" $(( s % 86400 / 3600 ))
  elif (( s >= 3600 )); then printf ' ↻%dh%02dm' $(( s / 3600 )) $(( s % 3600 / 60 ))
  else printf ' ↻%dm' $(( s / 60 )); fi
}

fmt_dur() { # ms -> 47m / 2h05m
  local m=$(( $1 / 60000 ))
  (( m >= 60 )) && printf '%dh%02dm' $(( m / 60 )) $(( m % 60 )) || printf '%dm' "$m"
}

# Local spend tracking: remember each session's latest cost, then sum by day / month.
# Estimate only: this machine, list-price cost, a session counts toward the date it was last updated.
day_total=""; month_total=""
if [[ -n $cost && -n $sid ]]; then
  f=~/.claude/spend.json
  today=$(date +%F); mon=$(date +%Y-%m); old=$(date -d '-62 days' +%F)
  [[ -f $f ]] || echo '{}' > "$f"
  {
    flock -x 9
    tmp=$(jq --arg id "$sid" --arg d "$today" --argjson c "$cost" --arg old "$old" \
      '.[$id] = {date: $d, cost: $c} | with_entries(select(.value.date >= $old))' "$f" 2>/dev/null) \
      && printf '%s\n' "$tmp" > "$f"
    read -r day_total month_total < <(jq -r --arg d "$today" --arg m "$mon" \
      '[ ([.[] | select(.date == $d) | .cost] | add // 0), ([.[] | select(.date | startswith($m)) | .cost] | add // 0) ] | @tsv' "$f" 2>/dev/null)
  } 9>"$f.lock"
fi

# Line 1: model, timer, context, usage
out="\033[36m${model}\033[0m"
[[ -n $dur ]] && out+=" │ ⏱ $(fmt_dur "$dur")"
if [[ -n $ctx ]]; then
  out+=" │ ctx $(bar "$ctx")"
  (( ${ctx%.*} >= 85 )) && out+=" \033[31m⚠ /compact\033[0m"
fi
[[ -n $cost ]] && out+=" │ sess \$$(printf '%.2f' "$cost")"
[[ -n $day_total ]] && out+=" │ today \$$(printf '%.2f' "$day_total") │ month \$$(printf '%.2f' "$month_total")"
[[ -n $h5 ]]   && out+=" │ 5h $(bar "$h5")$(reset_in "$h5r")"
[[ -n $d7 ]]   && out+=" │ 7d $(bar "$d7")$(reset_in "$d7r")"
printf '%b\n' "$out"

# Line 2: folder + git branch (skipped when no directory is reported)
if [[ -n $dir ]]; then
  line2="${dir##*/}"
  br=$(git -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null || git -C "$dir" rev-parse --short HEAD 2>/dev/null)
  if [[ -n $br ]]; then
    [[ -n $(git -C "$dir" status --porcelain 2>/dev/null) ]] && br+="*"
    line2+=" \033[35m${br}\033[0m"
  fi
  printf '%b\n' "$line2"
fi
