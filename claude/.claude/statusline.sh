#!/usr/bin/env bash
# Claude Code status line (statusLine in ~/.claude/settings.json, set by install.sh).
# Reads the session as JSON on stdin and prints one line:
#   Opus 5.5 high · dotfiles  main* · ctx 23% · 5h 41%
# Colours are the terminal's own 16, so they follow the Nord theme, light or dark.
# Context and the plan's 5-hour limit go yellow from 50% and red from 80%; the
# weekly limit only shows once it passes 50%.

input=$(cat)
IFS=$'\x1f' read -r model effort dir ctx five_hour seven_day < <(
    jq -r '[
        (.model.display_name // .model.id // "?"),
        (.effort.level // ""),
        (.workspace.current_dir // .cwd // ""),
        (.context_window.used_percentage // "" | if . == "" then . else floor end),
        (.rate_limits.five_hour.used_percentage // "" | if . == "" then . else floor end),
        (.rate_limits.seven_day.used_percentage // "" | if . == "" then . else floor end)
    ] | map(tostring) | join("\u001f")' <<<"$input"
)

reset=$'\e[0m' bold=$'\e[1m' dim=$'\e[2m'
blue=$'\e[34m' cyan=$'\e[36m' green=$'\e[32m' yellow=$'\e[33m' red=$'\e[31m'
sep=" ${dim}·${reset} "

# A percentage, coloured by how close it is to the limit
level() {
    local colour=$green
    (($1 >= 50)) && colour=$yellow
    (($1 >= 80)) && colour=$red
    printf '%s%s%%%s' "$colour" "$1" "$reset"
}

line="${bold}${model}${reset}"
[[ -n $effort ]] && line+=" ${dim}${effort}${reset}"

if [[ -n $dir ]]; then
    line+="${sep}${blue}${dir##*/}${reset}"
    # Branch, with * when the tree has changes; no index lock, so it never
    # gets in the way of git commands Claude is running
    if branch=$(git -C "$dir" --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null ||
        git -C "$dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null); then
        [[ -n $(git -C "$dir" --no-optional-locks status --porcelain 2>/dev/null | head -1) ]] && branch+="*"
        line+=" ${cyan} ${branch}${reset}"
    fi
fi

[[ -n $ctx ]] && line+="${sep}ctx $(level "$ctx")"
[[ -n $five_hour ]] && line+="${sep}5h $(level "$five_hour")"
[[ -n $seven_day ]] && ((seven_day >= 50)) && line+="${sep}7d $(level "$seven_day")"

printf '%s\n' "$line"
