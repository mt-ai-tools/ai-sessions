# ai-sessions

Remote access to Claude Code sessions: the way from your own machine into
the sessions a server keeps running.

Made for Claude Code, and for any use of it. A session is whatever Claude
is doing in a folder on the server; nothing here assumes code. Runs on
macOS and Linux.

Where it stops: it holds no session of its own and starts nothing on its
own account. It reaches the server only while you run it, keeps nothing on
your machine beyond the files it writes into the sessions folder, and
knows nothing about what happens inside a session.

## The server

Any machine you can reach over SSH, wherever it is hosted. It needs:

- A stable address, a fixed IP or a hostname. If you host it yourself,
  give it a reservation on the router or a static address, so it does not
  move under the config.
- SSH login with your key. Put your public key on it once
  (`ssh-copy-id user@host`) and confirm `ssh user@host` gets in without a
  password. No other SSH configuration is needed.
- tmux (`apt install tmux`, or your platform's equivalent). Every session
  lives inside tmux; that is what lets it outlive your connection.
- Claude Code, installed for the login user and signed in.

## Your machine

- A clone of this repository.
- `config.sample` copied to `config` beside it, with the server filled in.
  `config` is ignored by version control.
- Nothing to install: bash and ssh, which macOS and Linux ship.

## Use

`scripts/refresh.command` asks the server what it keeps running and writes
the sessions folder: one file per session, named after it. Open a session's
file and a terminal attaches to it; close the window and the session keeps
running. `scripts/new.command` asks for a name and a folder on the server,
starts Claude there inside tmux, and attaches.

On macOS, double-click the files. On Linux, run them from a terminal, for
example `bash scripts/refresh.command`, or set your file manager to run
scripts on a click.

The sessions folder is a snapshot from the last refresh. A session started
elsewhere shows up on the next one, provided it was started inside tmux.

## Develop

```sh
scripts/test.command
```
