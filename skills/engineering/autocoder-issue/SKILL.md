---
name: autocoder-issue
description: Open an issue for the Workcenter autocoder from any repo. Creates the six fwd- labels when the repo lacks them, writes the issue in the shape the autocoder reads (what, done when, what happens at the end), assigns it to the operator and labels it for the evening run or for straight away. Works on GitHub through `gh` and on Lely's GitLab through `glab`. Use when the operator says "maak een autocoder issue", "zet dit op de autocoder", "laat de autocoder dit doen", "autocoder issue voor ...", asks for the autocoder labels in a repo, or invokes /fwd:autocoder-issue.
---

# Open an issue the autocoder can pick up

The autocoder is a nightly run on the Workcenter. It finds every open issue
**assigned to the operator** carrying one of four ready labels, and gives each
one a Claude Code session of its own. The label is the whole interface: nothing
else marks an issue as ready.

This skill makes such an issue from whatever the operator just described, in
whichever repo is at hand, and makes sure the labels exist first.

Two things decide whether the run ever sees the issue. Both are this skill's
job, and both are checked afterwards:

1. the issue is **assigned to the operator**
2. the issue carries **one ready label**

## 1. Repo and host

Run `git remote -v` in the current directory.

| Remote host | Tool | Everything below uses |
| --- | --- | --- |
| `github.com` | `gh` | `gh ...` inside the clone |
| Lely's GitLab | `glab` | `glab ... --repo <group>/<project>` |

The operator names another repo than the one he is standing in: add
`--repo <owner>/<name>` to every `gh` call. Outside a clone, `--repo` is
required.

Stop and say so, without creating anything, when:

- the directory is not a git repo and no `--repo` was named
- `gh auth status` (or `glab auth status`) is not logged in

## 2. The six labels

The run reads four ready labels and writes two outcome labels. A repo that
misses one of the outcome labels breaks a run halfway: the session finishes and
the label that records it cannot be set.

| Label | What it means |
| --- | --- |
| `fwd-autocoder` | code this, in the evening run |
| `fwd-autocoder-now` | code this, in the next `--now` run |
| `fwd-linkedin` | research and write a post, evening run |
| `fwd-linkedin-now` | research and write a post, next `--now` run |
| `fwd-autocoder-done` | the run finished it |
| `fwd-autocoder-blocked` | a human has to look |

Create all six, always, whichever lane the issue is in. On GitHub `--force`
makes it safe to repeat: it updates an existing label instead of failing.

```sh
gh label create fwd-autocoder         --color 1D76DB --description "Autocoder: code this, evening run" --force
gh label create fwd-autocoder-now     --color 0052CC --description "Autocoder: code this, next --now run" --force
gh label create fwd-linkedin          --color 5319E7 --description "Autocoder: research and write a post, evening run" --force
gh label create fwd-linkedin-now      --color 6F42C1 --description "Autocoder: research and write a post, next --now run" --force
gh label create fwd-autocoder-done    --color 0E8A16 --description "Autocoder: finished" --force
gh label create fwd-autocoder-blocked --color D93F0B --description "Autocoder: a human has to look" --force
```

GitLab has no `--force`. Read what is there and create only what is missing:

```sh
glab label list --repo <group>/<project>
glab label create --repo <group>/<project> --name fwd-autocoder --color '#1D76DB' --description "Autocoder: code this, evening run"
```

Do this silently. Report it in one line at the end -- how many labels were
created, how many were already there -- never as a question.

## 3. The issue, in the shape the session reads

The session that picks this up reads the body and every comment, and asks
nobody anything: where the issue is unclear, it stops and marks itself blocked.
So three things have to be in the body, under these headings:

```markdown
## What

<what has to happen, in the operator's own words, sharpened>

## Done when

<how the session knows it is finished: a test that passes, a page that renders,
a command whose output changes>

## At the end

<one of: open a PR / push to branch <name> / do not push>
```

Write **What** from what the operator said. Sharpen it, never invent scope.

**Done when** and **At the end** are the two the session cannot guess. Derive
them where the operator's words allow:

| The operator said | Done when | At the end |
| --- | --- | --- |
| "fix the failing test in X" | that test passes and the suite stays green | open a PR |
| "add flag --foo to the CLI" | `<cmd> --foo` does <the described thing>, with a test | open a PR |
| nothing about either | -- | -- |

Where you cannot derive one of them, **ask the operator for that one thing**
and nothing else. One question, then write the issue. A guessed "done when" is
what turns a night of work into a comment saying the session could not read the
issue.

Leaving **At the end** out is allowed and means a draft PR: that is the
autocoder's own default. Write it out anyway, so the issue says what will
happen.

For the linkedin lane the three headings stay, with **Done when** describing
the post: subject, angle, length, where it should land.

## 4. Create, assign, label

One ready label per issue. The default is the evening lane.

| The operator said | Label |
| --- | --- |
| nothing about timing | `fwd-autocoder` |
| "nu", "straight away", "vandaag nog" | `fwd-autocoder-now` |
| "linkedin", "post", "artikel" | `fwd-linkedin` |
| linkedin **and** now | `fwd-linkedin-now` |

GitHub, with the body in a heredoc:

```sh
gh issue create \
  --title "<one line, imperative>" \
  --assignee @me \
  --label fwd-autocoder \
  --body "$(cat <<'EOF'
## What
...
EOF
)"
```

GitLab resolves no `@me` for an assignee. Read the username first:

```sh
me=$(glab api /user --jq .username)
glab issue create --repo <group>/<project> --title "..." --assignee "$me" --label fwd-autocoder --description "..."
```

## 5. Check what landed, then report

The two things that decide whether the run sees the issue are worth one call:

```sh
gh issue view <number> --json url,assignees,labels \
  --jq '{url, assignees: [.assignees[].login], labels: [.labels[].name]}'
```

An empty `assignees` means the run will never see the issue. Say that plainly
and name the reason you found -- no push access to the repo is the usual one.

Report in four lines:

- the issue URL and title
- the label it carries, and what that means: tonight's run, or the next `--now`
- what the run will do at the end, from the **At the end** section
- labels created versus already there

## What this skill does not do

- It does not start a run. `dev run-autocoder` is the operator's, on the
  Workcenter, and a timer runs it at 23:30 Amsterdam time.
- It does not touch the account map, `~/.workcenter/config.yml`. That table
  says which account directory a repo belongs to when the Workcenter has to
  clone it. A repo already on the machine is used where it is. An owner that is
  missing there means the run skips the issue with a comment saying so -- worth
  mentioning to the operator when you are on the Workcenter and
  `grep <owner> ~/.workcenter/config.yml` finds nothing, but never worth
  editing on your own.
- It does not work the issue. `/autocoder <url>` does that, in a session of its
  own.
