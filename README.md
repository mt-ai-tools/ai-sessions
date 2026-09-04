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

A session here is a tmux session on the server with one Claude running
in one folder, under the tmux name you give it. Several projects on the
server are several tmux sessions, one per project, each in its own
folder; two Claudes on one project are two tmux sessions. The folder is
chosen when a tmux session is started, never in the config.

`scripts/new-session` asks for a tmux name and a folder on the server,
relative to the login user's home or absolute, and starts Claude there
inside tmux, attached. A folder the server does not have is refused. The tmux name becomes the
file's name, so name a tmux session the way you want to see it in the
folder.

`scripts/watch-sessions` asks the server which tmux sessions it keeps
running and writes the sessions folder: one file per tmux session, named
after it. It keeps asking, every half minute unless the config says otherwise,
until you stop it. Open a file and a terminal attaches to that tmux
session; close the window and it keeps running.

Open the files in a terminal.

The sessions folder is as fresh as the last time watch asked. A tmux
session started elsewhere shows up on the next round; a Claude started
outside tmux never does. On a server shared with others, the config can name the tmux
sessions to show; left empty, every tmux session is shown.

## Develop

```sh
scripts/test
```
