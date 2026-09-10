# ai-sessions

Remote access to Claude Code sessions: the way from your own machine into
the sessions a server keeps running.

Made for Claude Code, and for any use of it. A session is whatever Claude
is doing in a folder on the server; nothing here assumes code. Runs on
macOS and Linux.

Where it stops: it holds no session of its own and starts nothing on its
own account. It reaches the server only while you run it, keeps nothing on
your machine beyond the files it writes into the sessions folder, and
knows nothing about what happens inside a session. Where the server is
reached through Tailscale, it reads what Tailscale knows to say why a link
is lost; it never configures Tailscale.

## The server

Any machine you can reach over SSH, wherever it is hosted. It needs:

- SSH login with your key. Put your public key on it once
  (`ssh-copy-id user@host`) and confirm `ssh user@host` gets in without a
  password. No other SSH configuration is needed.
- tmux (`apt install tmux`, or your platform's equivalent). Every session
  lives inside tmux; that is what lets it outlive your connection.
- Claude Code, installed for the login user and signed in.
- An address that does not change. Which one depends on where you work
  from — the next section.

## Two ways to reach it

The tool reaches the server through one ssh command, so either way is a
matter of what the config's `SERVER` points at. Nothing else differs.

**On the server's own network.** Your machine and the server share a LAN.

- Server: a fixed address on that network. Give it a reservation on the
  router or a static IP, so it does not move under the config.
- Your machine: nothing to install. bash and ssh, which macOS and Linux
  ship.
- Config: `SERVER="user@192.168.1.20"`, or the LAN hostname.

**From anywhere.** You work from an office, a café, another city; the
server stays where it is. [Tailscale](https://tailscale.com) gives both
machines a name and an address that hold on every network, and carries
ssh between them encrypted, with no port opened on your router. On the
server's own network the traffic still goes straight across the LAN.

- Server: Tailscale installed and logged in to your account. Have it
  start with the machine: on Linux its service does; on macOS the App
  Store build runs only once a user is logged in to the desktop, so log
  that user in at boot or use the standalone build from tailscale.com.
  Then, in Tailscale's admin console, disable key expiry for the server —
  or one day, months on, it quietly stops answering until someone at it
  logs in again.
- Your machine: Tailscale installed and logged in to the same account, and
  running whenever you want the server. Disable key expiry for it too, or
  every few months ssh stops working until you run `tailscale up` and log
  in again. Turning expiry off is safe for a machine you keep with you:
  what it guards against is a lost device that stays logged in, and a
  lost device is removed in the admin console in seconds, expiry or not.
- Config: `SERVER="user@myserver"` with the server's Tailscale machine
  name, and `TAILSCALE_NODE="myserver"` beside it, so the tool can ask
  Tailscale about the server when the link fails.

Start with the first and move to the second when you need it: the config
changes, the session files and everything else stay.

## Your machine

- A clone of this repository.
- `config.sample` copied to `config` beside it, with the server filled in
  as above. `config` is ignored by version control.
- Nothing to install beyond bash and ssh — and Tailscale, for the second
  way.

## Use

A session here is a tmux session on the server with one Claude running
in one folder, under the tmux name you give it. Several projects on the
server are several tmux sessions, one per project, each in its own
folder; two Claudes on one project are two tmux sessions. The folder is
chosen when a tmux session is started, never in the config.

`scripts/add-session` asks for a tmux name and a folder on the server,
relative to the login user's home or absolute, and starts Claude there
inside tmux, attached. A folder the server does not have is refused.
The tmux name becomes the file's name, so name a tmux session the way you
want to see it in the folder.

`scripts/watch-sessions` asks the server which tmux sessions it keeps
running and writes the sessions folder: one file per tmux session, named
after it. It keeps asking, on a clock the config can set, until you stop
it. Open a file and a terminal attaches to that tmux session; close the
window and it keeps running.

A closed lid, or any sleep, loses the link to the server but not the
session. The window says so and attaches again as soon as the server
answers, so it is back in the session moments after the lid opens, without
a hand. Only a window closed on purpose, or ctrl-c while it waits, ends it.
A link that stays lost is tried less and less often, and when the config
names the server in Tailscale, each try says what Tailscale knows:
Tailscale is off on this machine, the server is offline, its key has run
out, or this machine has lost its route into the tailnet — Tailscale up on
both ends, but packets for the server leaving by the ordinary interface,
as happens when a network service is restarted by hand or another VPN
takes the route; restarting Tailscale on this machine puts it back.
The watch window says the same under ssh's error when its round fails.

`scripts/forward-port` asks for a port and brings it here for as long as
its window is open: a web app a session runs on the server at 3000 opens
in your browser at localhost:3000, from any network. Close the window and
the port is gone; two ports are two windows. Ports and sessions never
share a window, so what is forwarded is exactly the port windows you see,
and closing a session touches no port. A lost link is mended the way a
session's is, and the port comes back with it.

Open the files in a terminal. The window's title bar carries the tmux
name, so two windows into two sessions are told apart at the top; tmux
sets it on every attach, whether the window came from add-session or from
a file here. A terminal that adds the name of the command a tab runs
(macOS Terminal does) adds the file's name, which is the tmux name again,
so a tab too narrow for the whole title still ends in the session's name.

The sessions folder is as fresh as the last time watch asked. A tmux
session started elsewhere shows up on the next round; a Claude started
outside tmux never does. On a server shared with others, the config can name
the tmux sessions to show; left empty, every tmux session is shown.

## Before a trip

```sh
scripts/run-check
```

asks, from your machine, whether the server is ready: the config loads,
ssh gets in, tmux and Claude are there, and — through Tailscale — the
server is online, this machine has a route to it, the path is direct
rather than relayed, and its key is not about to run out. One line per
question. Run it before leaving the server's network, or whenever a
session file will not attach and you want to know why.

## Develop

```sh
scripts/self-check
```
