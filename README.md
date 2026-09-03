# ai-sessions

Remote access to agent sessions: the way from a developer's machine into
the sessions a server keeps running.

Where it stops: it holds no session of its own and starts nothing on its
own account. It needs a server that keeps every session inside tmux,
reachable over SSH by key, and a config file beside the sample naming
that server — the sample says what goes in it. Whatever runs inside a
session is the session's business.

## Use

Double-click the refresh script. The sessions folder then holds one file
per session running on the server, named after it. Double-click a session
file and a terminal opens attached to it; close the window, and the
session keeps running. The new script starts a session in a folder on the
server and attaches to it.

The sessions folder is a snapshot from the last refresh. A session started
elsewhere shows up on the next one.

## Develop

```sh
scripts/test.command
```
