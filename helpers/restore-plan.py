# Run on the server, by restore-sessions: reads the records Claude leaves
# for each of its running processes and says which Claude sessions to
# start again after the server went down, and which to leave, and why.
# Prints one line per record, tab-separated, oldest first:
#
#   restore <started ms> <tmux name> <folder> <session id>
#   skip    <started ms> <tmux name> <why>
#
# Claude writes ~/.claude/sessions/<pid>.json as it starts and removes it
# when it ends cleanly, so the ones a crash leaves behind are the Claudes
# that were running. The format is Claude Code's own and undocumented; a
# record missing what is needed is skipped and said, never guessed at.
#
# A record is left when:
#   - its Claude still runs: the server never went down, or this is the
#     second run of a restore and that session is back already;
#   - it is from a boot before the last one: its session was restored or
#     dropped then, and a record of it stayed behind;
#   - it ran outside tmux, so there is no session to give back;
#   - a later record holds the same tmux name or the same session;
#   - tmux already runs a session under that name;
#   - its folder is gone, or Claude kept no transcript of it to resume.
#
# Nothing here starts anything. Only the standard library: the server
# needs python3 and nothing more.
import glob
import json
import os
import subprocess
import sys

HOME = os.path.expanduser("~")
RECORDS = os.path.join(HOME, ".claude", "sessions")
PROJECTS = os.path.join(HOME, ".claude", "projects")

# Two boot times, each worked out to the second from a process's start,
# that lie this close are the same boot.
SAME_BOOT_SECONDS = 120


def boot_time():
    """When this boot began, in seconds since the epoch; None off Linux."""
    try:
        with open("/proc/stat") as f:
            for line in f:
                if line.startswith("btime "):
                    return int(line.split()[1])
    except OSError:
        pass
    return None


def record_boot(r):
    """When the boot a record's Claude started in began. Linux records say
    when the process started, in clock ticks since boot; subtracting that
    from when it started gives the boot. None when the record cannot say."""
    try:
        ticks = int(r["procStart"])
        return r["startedAt"] / 1000 - ticks / os.sysconf("SC_CLK_TCK")
    except (KeyError, ValueError, TypeError, OSError):
        return None


def still_running(r):
    """True when the record's own process runs: its pid lives and, where
    the record says when it started, it is the same process, not a later
    one that was handed the same pid."""
    pid = r.get("pid")
    if not isinstance(pid, int):
        return False
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        pass
    try:
        with open("/proc/%d/stat" % pid) as f:
            fields = f.read().rsplit(")", 1)[1].split()
        return str(r.get("procStart")) == fields[19]
    except (OSError, IndexError):
        return True


def tmux_sessions():
    try:
        out = subprocess.run(["tmux", "list-sessions", "-F", "#{session_name}"],
                             capture_output=True, text=True).stdout
    except OSError:
        return set()
    return set(out.splitlines())


def has_transcript(session_id):
    return bool(glob.glob(os.path.join(PROJECTS, "*", session_id + ".jsonl")))


def main():
    records = []
    for path in glob.glob(os.path.join(RECORDS, "*.json")):
        try:
            with open(path) as f:
                r = json.load(f)
            r["startedAt"] = int(r["startedAt"])
        except (OSError, ValueError, KeyError, TypeError):
            print("skip\t0\t%s\tunreadable record" % os.path.basename(path))
            continue
        # "<tmux name>:@window.%pane"; the name may hold a colon itself.
        tmux = r.get("tmux") or ""
        r["name"] = tmux.rsplit(":", 1)[0] if ":" in tmux else ""
        r["boot"] = record_boot(r)
        records.append(r)

    now_boot = boot_time()
    earlier = [r["boot"] for r in records if r["boot"] is not None
               and (now_boot is None or r["boot"] < now_boot - SAME_BOOT_SECONDS)]
    last_boot = max(earlier) if earlier else None
    running = tmux_sessions()
    names_taken, ids_taken = set(), set()

    # Newest first, so of two records under one name or one session the
    # later wins; printed oldest first, the order they are started in.
    lines = []
    for r in sorted(records, key=lambda r: r["startedAt"], reverse=True):
        name, sid, cwd = r["name"], r.get("sessionId") or "", r.get("cwd") or ""
        why = None
        if still_running(r):
            why = "its Claude still runs"
        elif not name:
            why = "it ran outside tmux"
        elif (r["boot"] is not None and last_boot is not None
              and abs(r["boot"] - last_boot) > SAME_BOOT_SECONDS
              and (now_boot is None or abs(r["boot"] - now_boot) > SAME_BOOT_SECONDS)):
            why = "it is from an earlier boot"
        elif name in names_taken or sid in ids_taken:
            why = "a later record holds the same name or session"
        elif name in running:
            why = "tmux already runs a session by that name"
        elif not sid:
            why = "the record names no session"
        elif not os.path.isdir(cwd):
            why = "its folder %s is gone" % cwd
        elif not has_transcript(sid):
            why = "Claude kept no transcript of it"
        if name and why != "it is from an earlier boot":
            names_taken.add(name)
            ids_taken.add(sid)
        if why:
            lines.append((r["startedAt"], "skip\t%d\t%s\t%s" % (r["startedAt"], name or "-", why)))
        else:
            lines.append((r["startedAt"], "restore\t%d\t%s\t%s\t%s" % (r["startedAt"], name, cwd, sid)))
    for _, line in sorted(lines):
        print(line)


if __name__ == "__main__":
    sys.exit(main())
