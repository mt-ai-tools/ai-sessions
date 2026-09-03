# ai-sessions

Remote access to agent sessions: the way from a developer's machine into
the sessions a server keeps running.

Where it stops: it holds no session of its own and starts nothing on its
own account. It needs a server that keeps every session inside tmux,
reachable over SSH by key, and a config file beside the sample naming
that server — the sample says what goes in it. Whatever runs inside a
session is the session's business.

## Develop

```sh
npm install
npm test
```
