# Background wait loops

A loop that waits for something — a file to appear, a log line to show up, a job
to finish — always runs under a hard deadline:

```bash
timeout 1800 bash -c 'until [ -f /path/to/marker ]; do sleep 2; done'
```

Without it the loop outlives the work it was watching. It then blocks the exit
prompt on this machine, which blocks restarts (updating Claude Code, for
instance).

- **Only wrap loops that watch or poll.** Never wrap a command that changes
  something itself — a migration, a build, a `git push`, a deploy. Killing those
  halfway causes real damage.
- **Exit code 124 means "not done yet", not "failed".** `timeout` returns 0 when
  the condition became true and 124 when the clock ran out. The work it was
  watching keeps running either way. Re-arm the loop if you still want the
  notification; never report failure on a 124 alone.
- 1800 seconds is the default ceiling. Use less when you know the wait is short.
