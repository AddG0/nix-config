#!/usr/bin/env bash
# Holds back commands that post text another person reads until write-for-people has loaded in this session.

input=$(cat)
session=$(jq -er '.session_id' <<<"$input")
loaded_flag="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/claude-write-for-people-gate/$session"

skills_that_post_text=(jira gitlab-mr investigate review-pr)

posting_commands=(
  # jira-cli: new tickets and comments, and rewording a ticket
  '(^|[/[:space:]])jira-cli[[:space:]]+(create|comment[[:space:]]+(add|edit))([[:space:]]|$)'
  '(^|[/[:space:]])jira-cli[[:space:]]+update[[:space:]].*--(description|summary)'
  # glab: new MRs and issues, notes, and retitling or redescribing
  '(^|[[:space:]])glab[[:space:]]+(mr|issue)[[:space:]]+(create|note[[:space:]]+(create|update))([[:space:]]|$)'
  '(^|[[:space:]])glab[[:space:]]+(mr|issue)[[:space:]]+update[[:space:]].*(--description|--title|[[:space:]]-d|[[:space:]]-t)([[:space:]=]|$)'
  # gh: new PRs and issues, comments and reviews
  '(^|[[:space:]])gh[[:space:]]+(pr|issue)[[:space:]]+(create|comment|review)([[:space:]]|$)'
  # gh api and glab api: writing a comment, review, note or discussion (the endpoint and write flag in either order)
  '(^|[[:space:]])(gh|glab)[[:space:]]+api[[:space:]].*(comments|reviews|notes|discussions).*[[:space:]](-X[[:space:]]*(POST|PATCH|PUT|post|patch|put)|--method[[:space:]=]+(POST|PATCH|PUT|post|patch|put)|-f|-F|--field|--raw-field|--input)([[:space:]=]|$)'
  '(^|[[:space:]])(gh|glab)[[:space:]]+api[[:space:]](.*[[:space:]])?(-X[[:space:]]*(POST|PATCH|PUT|post|patch|put)|--method[[:space:]=]+(POST|PATCH|PUT|post|patch|put)|-f|-F|--field|--raw-field|--input)[[:space:]=].*(comments|reviews|notes|discussions)'
)

skill_loaded() {
  [ -e "$loaded_flag" ]
}

posts_text() {
  grep -qEf <(printf '%s\n' "${posting_commands[@]}") <<<"$1"
}

skill_posts_text() {
  printf '%s\n' "${skills_that_post_text[@]}" | grep -qxF -- "$1"
}

remember_skill_load() {
  mkdir -p "$(dirname "$loaded_flag")"
  touch "$loaded_flag"
}

forget_skill_load() {
  rm -f "$loaded_flag"
}

nudge_before_drafting() {
  skill_loaded && return
  jq -nc '{hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: "This skill posts text another person reads. Load the write-for-people skill before drafting it."
  }}'
}

on_skill_loaded() {
  if [ "$1" = write-for-people ]; then
    remember_skill_load
  elif skill_posts_text "$1"; then
    nudge_before_drafting
  fi
}

hold_post_until_loaded() {
  skill_loaded && return
  posts_text "$1" || return 0
  jq -nc '{hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "This command posts text another person reads. Load the write-for-people skill, revise the text against it, then run the command again."
  }}'
}

case $(jq -er '.hook_event_name' <<<"$input") in
PostToolUse) on_skill_loaded "$(jq -r '.tool_input.skill // empty' <<<"$input")" ;;
SessionStart) forget_skill_load ;; # compaction drops loaded skill bodies
PreToolUse) hold_post_until_loaded "$(jq -r '.tool_input.command // empty' <<<"$input")" ;;
esac
