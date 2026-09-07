# Passive system audit

Install with `~/.rotz/bin/rotz install /arch/system-audit`. This enables two
user timers: memory/service observations every minute and selected storage sizes
daily. No extra Python packages are required. Python 3, systemd and GNU du must
already be installed. The module assumes this checkout is at `~/.dotfiles`.

Records live in `${XDG_STATE_HOME:-~/.local/state}/system-audit`, with private
permissions, seven UTC calendar days of retention, and a 16 MiB daily limit per
stream (224 MiB maximum across seven days). Rotation runs on every write;
disabled timers leave their remaining files in place. No command lines,
environment variables, database contents or application logs are collected.

Minute samples include available memory, swap, kernel pressure, PID plus process
start ticks and boot ID, selected process RSS, and memory/CPU counters for up to
200 running user services. CPU counters are cumulative; compare differences
only within the same service InvocationID, which identifies restarts. Process RSS can double-count shared
pages; cgroup counters include cache and descendants. Missing accounting values
and inaccessible services are not zero consumption. Container service cgroups
provide visibility even when their main process name does not match the selected
RomM, Valkey, Redis, Betterbird, Hyprland and PipeWire names. These are observations,
not leak diagnoses: compare equivalent idle periods across a normal working day.

Storage measurements target named package, dependency and container stores,
with same-filesystem traversal, 45 seconds per store and a four-minute total
budget. They run with idle I/O scheduling and low CPU priority. Inaccessible
stores produce an error entry; when du provides a partial total it is retained
with `incomplete=true` and represents a lower bound. Daily records also include
filesystem capacity, free bytes and user-available bytes for `/`, `/home` and
`/mnt/windows`, or an explicit unmounted/error indication. The list deliberately does not walk every project
for `.next`, `target` or `.turbo` directories. Seven daily samples are needed to
assess growth; large size alone does not establish unbounded growth.

Validate without recording: `python3 arch/system-audit/audit.py sample --stdout`.
Run tests: `python3 -m unittest discover -s arch/system-audit`.
Inspect activation: `systemctl --user list-timers 'system-audit-*'`.
Stop collection: `systemctl --user disable --now system-audit-sample.timer system-audit-storage.timer`.
No cleanup, service shutdown or memory-limit changes are performed.
