--[[--
Lookup backends of the hop lookup plugin.

Three backends are supported:

* `goldendict`: the word is sent to GoldenDict (the configured executable, one
  of the well known command names, the flatpak, the application known to
  KOReader on this device, or the `goldendict://` URL handler);
* `internal`: the word is looked up in KOReader's own dictionaries;
* `auto` (default): GoldenDict is probed first, and the internal dictionary
  is used as a fallback when it is not available.

@module koplugin.hop_lookup.hoplookup_lookup
--]]--

local Device = require("device")
local Event = require("ui/event")
local logger = require("logger")
local util = require("util")
local _ = require("gettext")
local T = require("ffi/util").template

local Lookup = {}

-- How long (in seconds) a GoldenDict probe is trusted.
Lookup.probe_ttl = 60

-- Command names GoldenDict is installed as, tried in this order after the
-- configured path. Debian/Ubuntu ship GoldenDict-ng as plain "goldendict".
Lookup.candidate_commands = {
    "goldendict",
    "goldendict-ng",
    "goldendict-qt6",
}

-- Flatpak application id of GoldenDict-ng.
Lookup.flatpak_app_id = "io.github.xiaoyifang.goldendict_ng"

--[[--
Arguments used to ask GoldenDict for `word`.

`window` is "popup" (scan popup / floating window) or "main" (main window).

Two flavours of GoldenDict exist and do not share the same options:

* GoldenDict-ng knows `-s`/`--popup` (force the popup) and `-m`/`--main-window`
  (force the main window);
* the original GoldenDict has no such option: a word sent to an already
  running instance is shown in its popup window, while a cold start opens the
  main window. In that case the command line is the same for both modes.

The flavour is auto-detected with `goldendict_flavor()`.
]]
function Lookup.goldendict_args(path, window, word, flavor, clean_env)
    flavor = flavor or Lookup.goldendict_flavor(path)
    local args = Lookup.command_args(path, clean_env)
    if flavor == "ng" then
        args[#args + 1] = window == "popup" and "-s" or "-m"
    end
    -- No `--`: the scanner never produces words starting with a dash, and the
    -- original GoldenDict would take a bare `--` as the word to look up.
    args[#args + 1] = word
    return args
end

--[[--
Full shell command line used to look `word` up, detached from KOReader (and
with its output thrown away).
]]
function Lookup.shell_command(args)
    return util.shell_escape(args) .. " >/dev/null 2>&1 &"
end

function Lookup.goldendict_command(path, window, word, flavor, clean_env)
    return Lookup.shell_command(Lookup.goldendict_args(path, window, word, flavor, clean_env))
end

--[[--
Arguments for the flatpak build (which is always GoldenDict-ng).
]]
function Lookup.flatpak_args(window, word, flavor)
    local args = { "flatpak", "run", Lookup.flatpak_app_id }
    if (flavor or "ng") == "ng" then
        args[#args + 1] = window == "popup" and "-s" or "-m"
    end
    args[#args + 1] = word
    return args
end

--[[--
Whether `command` (a path, or a command name looked up in $PATH) exists.
]]
function Lookup.command_exists(command)
    if type(command) ~= "string" or command == "" then
        return false
    end
    if command:find("/", 1, true) then
        return util.pathExists(command)
    end
    local ok, handle = pcall(io.popen, "command -v " .. util.shell_escape({ command }) .. " 2>/dev/null")
    if not ok or not handle then
        return false
    end
    local output = handle:read("*a")
    handle:close()
    return type(output) == "string" and output:gsub("%s", "") ~= ""
end

--[[--
Build the argument list used to run `command`.

When `clean_env` is set, LD_LIBRARY_PATH is dropped for that process: KOReader's
launcher may export it with its own library directory, which can hide the
system libraries an external program needs (this is a real failure mode on
AppImage / bundled builds).
]]
function Lookup.command_args(command, clean_env, ...)
    local args = {}
    if clean_env then
        args[#args + 1] = "env"
        args[#args + 1] = "-u"
        args[#args + 1] = "LD_LIBRARY_PATH"
    end
    args[#args + 1] = command
    for _, value in ipairs({ ... }) do
        if value ~= nil then
            args[#args + 1] = value
        end
    end
    return args
end

--[[--
Whether a command's output looks like the dynamic loader refusing to start it
(as opposed to the program's own output).
]]
local LOADER_ERRORS = {
    "error while loading shared libraries",
    "cannot open shared object file",
    "cannot execute",
    "permission denied",
    "no such file or directory",
}

function Lookup.looks_like_loader_error(text)
    local lower = (text or ""):lower()
    for _, pattern in ipairs(LOADER_ERRORS) do
        if lower:find(pattern, 1, true) then
            return true
        end
    end
    return false
end

--[[--
Value of an environment variable in KOReader's own process ("" when unset).
]]
function Lookup.environment(name)
    local value = os.getenv(name)
    if not value or value == "" then
        return ""
    end
    return value
end

--[[--
Run a shell command and tell whether it succeeded (used for cheap probes).
]]
function Lookup.command_succeeds(command)
    local ok, result = pcall(os.execute, command .. " >/dev/null 2>&1")
    if not ok then
        return false
    end
    return result == true or result == 0
end

--[[--
Read the output of a command (empty string when it cannot be run). Bounded by
`timeout` when available, so that an unexpected binary cannot freeze the UI.
]]
function Lookup.command_output(args, timeout_seconds)
    local command = util.shell_escape(args)
    if timeout_seconds then
        command = "if command -v timeout >/dev/null 2>&1; then timeout "
            .. tostring(timeout_seconds) .. " " .. command
            .. "; else " .. command .. "; fi"
    end
    local ok, handle = pcall(io.popen, command .. " 2>&1")
    if not ok or not handle then
        return ""
    end
    local output = handle:read("*a")
    handle:close()
    return type(output) == "string" and output or ""
end

--[[--
Find the external dictionary application known to KOReader's Device layer
(SDL desktop, Android, ...) matching the configured GoldenDict path.

Returns the entry of `Device:getExternalDictLookupList()` (a table looking
like `{ method, title, available, app, action }`) or nil.
]]
function Lookup.find_device_dict(path)
    if not Device.canExternalDictLookup or not Device:canExternalDictLookup() then
        return nil
    end
    local list = Device.getExternalDictLookupList and Device:getExternalDictLookupList() or {}
    local wanted = type(path) == "string" and path:lower() or ""
    for _, dict in ipairs(list) do
        local app = type(dict[4]) == "string" and dict[4]:lower() or ""
        if dict[3] and app ~= "" then
            if wanted ~= "" and (app == wanted or app:find(wanted, 1, true) or wanted:find(app, 1, true)) then
                return dict
            end
        end
    end
    for _, dict in ipairs(list) do
        local app = type(dict[4]) == "string" and dict[4]:lower() or ""
        if dict[3] and app:find("golden", 1, true) then
            return dict
        end
    end
    return nil
end

--[[--
First usable GoldenDict command line: the configured path when it exists,
then the well known command names.
]]
function Lookup.resolve_command(config)
    local candidates, seen = {}, {}
    local configured = config and config.goldendict_path
    if type(configured) == "string" and configured ~= "" then
        candidates[#candidates + 1] = configured
    end
    for _, name in ipairs(Lookup.candidate_commands) do
        candidates[#candidates + 1] = name
    end
    for _, candidate in ipairs(candidates) do
        if not seen[candidate] then
            seen[candidate] = true
            if Lookup.command_exists(candidate) then
                return candidate
            end
        end
    end
    return nil
end

--[[--
Whether GoldenDict-ng is installed as a flatpak.
]]
function Lookup.flatpak_available()
    if not Lookup.command_exists("flatpak") then
        return false
    end
    return Lookup.command_succeeds("flatpak info " .. Lookup.flatpak_app_id)
end

--[[--
Absolute path of a command (via `command -v`), or nil.
]]
function Lookup.command_path(command)
    local output = Lookup.command_output({ "command", "-v", command })
    output = output:gsub("%s", "")
    return output ~= "" and output or nil
end

--[[--
Which package owns `path` (pacman / dpkg / rpm), as reported by the package
manager, or nil.

On Arch and Debian both variants install the binary as `goldendict`, so the
package name is the only reliable way to tell them apart.
]]
function Lookup.owning_package(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end
    local tools = {
        { "pacman", "-Qo" },
        { "dpkg", "-S" },
        { "rpm", "-qf" },
    }
    for _, tool in ipairs(tools) do
        if Lookup.command_exists(tool[1]) then
            local output = Lookup.command_output({ tool[1], tool[2], path })
            local lower = output:lower()
            if lower:find("no package owns", 1, true) or lower:find("is not owned by any package", 1, true)
                or lower:find("not owned by any", 1, true) then
                return nil
            end
            if lower:find("goldendict", 1, true) then
                return output
            end
        end
    end
    return nil
end

--[[--
Desktop file registered for the `goldendict://` URL scheme (empty when none).
GoldenDict-ng registers "io.github.xiaoyifang.goldendict_ng.desktop", the
original registers "goldendict.desktop".
]]
function Lookup.url_scheme_handler()
    return Lookup.command_output({ "xdg-mime", "query", "default", "x-scheme-handler/goldendict" })
end

--[[--
Is KOReader itself running inside a Flatpak sandbox, and if so which app.

That matters a lot here: inside the sandbox `goldendict` resolves to the
*host* binary (seen under /run/host/...), and a host binary cannot load the
host's libraries from inside the sandbox. The supported ways out are running
the command on the host (flatpak-spawn --host) or handing the URI to the
desktop portal.
]]
function Lookup.flatpak_info()
    if Lookup._flatpak_info then
        return Lookup._flatpak_info
    end
    local info = { in_flatpak = false, app_id = nil }
    if util.pathExists("/.flatpak-info") then
        info.in_flatpak = true
        local content = ""
        local handle = io.open("/.flatpak-info", "r")
        if handle then
            content = handle:read("*a") or ""
            handle:close()
        end
        info.app_id = content:match("\nname=([^\n]+)") or content:match("^name=([^\n]+)")
    end
    Lookup._flatpak_info = info
    return info
end

--[[--
Can we run a command on the host from inside the sandbox?
(flatpak-spawn --host needs the org.freedesktop.Flatpak permission.)
]]
function Lookup.host_spawn_available()
    if not Lookup.flatpak_info().in_flatpak then
        return false
    end
    if not Lookup.command_exists("flatpak-spawn") then
        return false
    end
    return Lookup.command_succeeds("flatpak-spawn --host true")
end

--[[--
Arguments to run GoldenDict on the host, from inside the sandbox. The command
is given by name (a /run/host/... path only exists inside the sandbox).
]]
function Lookup.host_spawn_args(command_name, window, word, flavor)
    local args = { "flatpak-spawn", "--host", command_name }
    if (flavor or "ng") == "ng" then
        args[#args + 1] = window == "popup" and "-s" or "-m"
    end
    args[#args + 1] = word
    return args
end

--[[--
Whether the `goldendict://` URL scheme has a handler (so that a word can be
sent to GoldenDict through `xdg-open`).
]]
function Lookup.url_handler_available()
    if not Lookup.command_exists("xdg-open") then
        return false
    end
    return Lookup.url_scheme_handler():gsub("%s", "") ~= ""
end

--[[--
Goldendict desktop files installed on the system, as one string.
]]
function Lookup.desktop_files()
    local dirs = {
        "/usr/share/applications",
        "/usr/local/share/applications",
    }
    local home = os.getenv("HOME")
    if home then
        dirs[#dirs + 1] = home .. "/.local/share/applications"
    end
    local found = {}
    for _, dir in ipairs(dirs) do
        local output = Lookup.command_output({ "ls", "-1", dir })
        for line in output:gmatch("[^\n]+") do
            if line:lower():find("goldendict", 1, true) then
                found[#found + 1] = line
            end
        end
    end
    return table.concat(found, " ")
end

local function mentions_ng(text)
    local lower = (text or ""):lower()
    return lower:find("goldendict%-ng", 1) ~= nil
        or lower:find("goldendict_ng", 1) ~= nil
        or lower:find("goldendictng", 1) ~= nil
        or lower:find("xiaoyifang", 1) ~= nil
end

--[[--
Tell GoldenDict-ng and the original GoldenDict apart, returning the variant
("ng", "original" or nil) and a short explanation of the evidence.

Evidence is collected from the cheapest sources first:

1. the command name itself ("goldendict-ng");
2. the package that owns the binary (pacman/dpkg/rpm) -- needed because
   GoldenDict-ng is usually installed as plain `goldendict`;
3. the desktop file registered for the `goldendict://` URL scheme;
4. the installed desktop files;
5. `--help`, which mentions `--scanpopup` (ng only) or `--toggle-scan-popup`
   (original only). This one may be slow or produce nothing (e.g. when an
   instance is already running), hence it comes last.

Never use `--version`/`-v`: the original does not know it and would treat it
as the word to look up.
]]
function Lookup.detect_flavor(command, help_timeout, clean_env, via_host)
    local basename = ((command or ""):match("([^/]+)$") or ""):lower()
    if basename:find("ng", 1, true) then
        return "ng", T(_("command name “%1”"), basename)
    end

    local path = command
    if path and not path:find("/", 1, true) then
        path = Lookup.command_path(path)
    end
    local package = Lookup.owning_package(path)
    if package then
        if mentions_ng(package) then
            return "ng", T(_("package “%1”"), package:gsub("%s+$", ""))
        end
        return "original", T(_("package “%1”"), package:gsub("%s+$", ""))
    end

    local handler = Lookup.url_scheme_handler()
    if handler:gsub("%s", "") ~= "" then
        if mentions_ng(handler) then
            return "ng", T(_("URL handler “%1”"), handler:gsub("%s+$", ""))
        end
        return "original", T(_("URL handler “%1”"), handler:gsub("%s+$", ""))
    end

    local desktop = Lookup.desktop_files()
    if desktop ~= "" then
        if mentions_ng(desktop) then
            return "ng", T(_("desktop file “%1”"), desktop)
        end
        return "original", T(_("desktop file “%1”"), desktop)
    end

    if help_timeout ~= false then
        local probe_args
        if via_host then
            probe_args = { "flatpak-spawn", "--host", command, "--help" }
        else
            probe_args = Lookup.command_args(command, clean_env, "--help")
        end
        local output = Lookup.command_output(probe_args, help_timeout or 2)
        if output:find("--scanpopup", 1, true) then
            return "ng", _("--help mentions --scanpopup")
        end
        if output:find("--toggle%-scan%-popup") then
            return "original", _("--help mentions --toggle-scan-popup")
        end
    end
    return nil, _("no evidence found")
end

--[[--
Probe GoldenDict once (cached for `probe_ttl` seconds).

Returns a table:
    { configured = <string>, command = <path or nil>, flavor = "ng"|"original"|nil,
      flatpak = <bool>, device_dict = <table or nil>, url_handler = <bool>,
      available = <bool> }

`available` means "a lookup can be started", whatever the mean.
]]
function Lookup.probe(configured_path)
    local now = os.time and os.time() or 0
    local cache = Lookup._probe_cache
    if cache and cache.configured == configured_path and (now - cache.time) < Lookup.probe_ttl then
        return cache
    end
    local probe = {
        configured = configured_path,
        time = now,
        command = nil,
        flavor = nil,
        flatpak = false,
        device_dict = nil,
        url_handler = false,
        available = false,
    }
    probe.command = Lookup.resolve_command({ goldendict_path = configured_path })
    if probe.command then
        probe.command_path = Lookup.command_path(probe.command) or probe.command
        probe.missing_libraries = Lookup.missing_libraries(probe.command_path)
        if #probe.missing_libraries > 0 then
            local flatpak = Lookup.flatpak_info()
            if flatpak.in_flatpak then
                -- The "executable" is the host's binary, seen through
                -- /run/host/...: it cannot load the host's libraries from
                -- inside the sandbox. Run it on the host instead, and fall
                -- back on the URI portal when that is not permitted.
                probe.host_spawn = Lookup.host_spawn_available()
                probe.url_handler = Lookup.command_exists("xdg-open")
                    or Lookup.command_exists("gio")
                if probe.host_spawn then
                    probe.available = true
                    probe.host_spawn_note = T(
                        _("KOReader runs as a Flatpak, so GoldenDict is started on the host with %1"),
                        "flatpak-spawn --host")
                elseif probe.url_handler then
                    -- No permission to run host commands: hand the word to the
                    -- desktop portal instead, which opens it on the host.
                    probe.available = true
                    probe.url_route_note = _("KOReader runs as a Flatpak: the word is handed to the desktop portal (goldendict://), which opens it on the host. The popup/main mode cannot be forced this way, and a window opened by another application this way may behave like a temporary scan popup (it can vanish when the pointer or the focus moves) — allow host commands for a normal launch.")
                else
                    probe.available = false
                    probe.broken = true
                    probe.flatpak_problem = true
                    probe.broken_reason = _("this is the host's GoldenDict, and a Flatpak sandbox cannot run it")
                end
            else
                -- Same environment trick as above: LD_LIBRARY_PATH exported by
                -- the launcher may be hiding the system libraries.
                local clean_line = Lookup.binary_check(probe.command, 3, true)
                if clean_line ~= "" and not Lookup.looks_like_loader_error(clean_line) then
                    probe.clean_env = true
                    probe.env_reason = T(_("LD_LIBRARY_PATH hides %1"),
                        table.concat(probe.missing_libraries, ", "))
                else
                    probe.available = false
                    probe.broken = true
                    probe.broken_reason = T(_("missing libraries: %1"),
                        table.concat(probe.missing_libraries, ", "))
                end
            end
        end
        probe.flavor, probe.evidence = Lookup.detect_flavor(probe.command,
            probe.host_spawn and 5 or nil, probe.clean_env, probe.host_spawn)
        if not probe.flavor then
            -- Inconclusive: GoldenDict-ng is the variant current distributions
            -- ship, and the only one that can be asked for the popup, so
            -- assume it. "Check GoldenDict" shows the evidence and the
            -- resulting command line.
            probe.flavor = "ng"
            probe.evidence = _("assumed (no evidence found)")
            probe.assumed = true
        end
        if not probe.broken then
            probe.available = true
        end
    else
        probe.flatpak = Lookup.flatpak_available()
        if probe.flatpak then
            probe.flavor = "ng"
            probe.available = true
        else
            probe.device_dict = Lookup.find_device_dict(configured_path)
            if probe.device_dict then
                probe.flavor = "device"
                probe.available = true
            else
                probe.url_handler = Lookup.url_handler_available()
                probe.available = probe.url_handler
            end
        end
    end
    Lookup._probe_cache = probe
    logger.info("hop_lookup: goldendict probe:", probe.configured, "->",
        probe.command or (probe.flatpak and "flatpak") or (probe.device_dict and "device")
        or (probe.url_handler and "url-handler") or "not found", probe.flavor)
    return probe
end

--[[--
Is GoldenDict usable right now?
]]
function Lookup.goldendict_available(config)
    return Lookup.probe(config and config.goldendict_path).available
end

--[[--
Variant of the configured GoldenDict ("ng", "original", "device", ...).
]]
function Lookup.goldendict_flavor(path)
    return Lookup.probe(path).flavor
end

--[[--
Percent-encode a word for the `goldendict://` URL scheme.
]]
function Lookup.url_encode(text)
    return (text:gsub("[^%w%-%._~]", function(ch)
        return string.format("%%%02X", ch:byte())
    end))
end

--[[--
Send `word` to GoldenDict. Returns true when a lookup was started.

The means are tried in order of preference: a real executable (so that the
popup/main window can be chosen), the flatpak, the application known to the
device layer, and finally the `goldendict://` URL handler.
]]
function Lookup.run_goldendict(config, word)
    local probe = Lookup.probe(config.goldendict_path)
    if probe.broken then
        logger.warn("hop_lookup: goldendict cannot run:", probe.broken_reason)
        return false
    end
    local flavor, args
    if probe.host_spawn then
        flavor = probe.flavor
        args = Lookup.host_spawn_args(Lookup.process_name(probe), config.goldendict_window, word,
            probe.flavor)
    elseif probe.command and not probe.broken and not probe.url_route_note then
        flavor = probe.flavor
        args = Lookup.goldendict_args(probe.command, config.goldendict_window, word,
            probe.flavor, probe.clean_env)
    elseif probe.flatpak then
        flavor = "ng"
        args = Lookup.flatpak_args(config.goldendict_window, word, flavor)
    end
    if args then
        local command = Lookup.shell_command(args)
        logger.info("hop_lookup: launching", command)
        if pcall(os.execute, command) then
            return true
        end
    end
    if probe.device_dict and Device.doExternalDictLookup then
        logger.info("hop_lookup: external dict lookup", word, probe.device_dict[1])
        pcall(function() Device:doExternalDictLookup(word, probe.device_dict[1], nil) end)
        return true
    end
    if probe.url_handler then
        -- No `?target=` parameter: only recent GoldenDict-ng understands it, and
        -- the others look the whole "word?target=main" up as a single word.
        -- Which window it uses is then up to the host's GoldenDict settings.
        local url = "goldendict://" .. Lookup.url_encode(word)
        local opener = Lookup.command_exists("xdg-open") and "xdg-open" or "gio"
        local args = { opener }
        if opener == "gio" then
            args[#args + 1] = "open"
        end
        args[#args + 1] = url
        logger.info("hop_lookup: handing the word to the desktop portal:", opener, url)
        if pcall(os.execute, Lookup.shell_command(args)) then
            return true
        end
    end
    return false
end

--[[--
Look `word` up in KOReader's dictionaries. `box` is the optional screen
rectangle of the word, used by the dictionary window to highlight it.
]]
function Lookup.run_internal(ui, word, box)
    local boxes
    if box and box.w and box.w > 0 then
        boxes = { { x = box.x, y = box.y, w = box.w, h = box.h } }
    end
    ui:handleEvent(Event:new("LookupWord", word, true, boxes))
    return true
end

--[[--
Perform a lookup with the configured backend.

Returns the backend that was actually used ("goldendict" or "internal"), or
nil plus a message when an explicitly selected backend was unavailable.
]]
function Lookup.perform(ui, config, word, box)
    if not word or word == "" then
        return nil, "empty word"
    end
    local probe = Lookup.probe(config and config.goldendict_path)
    local reason = probe.broken and probe.broken_reason or nil
    if config.backend == "goldendict" then
        if Lookup.run_goldendict(config, word) then
            return "goldendict"
        end
        return nil, "goldendict", reason
    end
    if config.backend == "internal" then
        Lookup.run_internal(ui, word, box)
        return "internal"
    end
    -- auto: probe GoldenDict first, then fall back on the internal dictionary.
    if probe.available and Lookup.run_goldendict(config, word) then
        return "goldendict"
    end
    Lookup.run_internal(ui, word, box)
    return "internal", nil, reason
end

--[[--
Whether we can run shell commands at all (KOReader itself uses os.execute() to
launch external dictionaries, so this should always work on Linux).
]]
function Lookup.shell_check()
    local marker = "hop_lookup_shell_ok"
    local output = Lookup.command_output({ "echo", marker })
    return output:find(marker, 1, true) ~= nil
end

--[[--
Make the executable print something, so that a "found but unusable" binary is
told apart from a working one. Returns the first line of its --help output
(empty when it printed nothing).
]]
function Lookup.binary_check(command, timeout_seconds, clean_env, via_host)
    if type(command) ~= "string" or command == "" then
        return ""
    end
    local probe_args
    if via_host then
        probe_args = { "flatpak-spawn", "--host", command, "--help" }
    else
        probe_args = Lookup.command_args(command, clean_env, "--help")
    end
    local output = Lookup.command_output(probe_args, timeout_seconds or 5)
    local first = output:match("[^\n]*%S[^\n]*")
    return first or ""
end

--[[--
Running processes whose *name* is exactly `name`, as a list of pids (empty
when there are none or when no process tool is available).

The exact match matters: `pgrep -f goldendict` also matches our own launcher
shell (whose command line contains the word), which would look like a
successful start.
]]
function Lookup.running_processes(name)
    if type(name) ~= "string" or name == "" then
        return ""
    end
    if Lookup.command_exists("pgrep") then
        return Lookup.command_output({ "pgrep", "-x", name }):gsub("%s+$", "")
    end
    if Lookup.command_exists("pidof") then
        return Lookup.command_output({ "pidof", name }):gsub("%s+$", "")
    end
    return ""
end

--[[--
Shared libraries the executable needs but cannot find, as a list.

A binary that is installed but whose libraries are missing (broken package,
partial upgrade) cannot run at all; `ldd` tells us that without starting it.
]]
function Lookup.missing_libraries(command)
    local missing = {}
    if type(command) ~= "string" or command == "" then
        return missing
    end
    local path = command
    if not path:find("/", 1, true) then
        path = Lookup.command_path(path)
    end
    if not path or not Lookup.command_exists("ldd") then
        return missing
    end
    local output = Lookup.command_output({ "ldd", path })
    for line in output:gmatch("[^\n]+") do
        local library = line:match("^%s*(%S+)%s*=>%s*not found")
        if library then
            missing[#missing + 1] = library
        end
    end
    return missing
end

--[[--
Name of the GoldenDict process, for the launch checks.
]]
function Lookup.process_name(probe)
    if probe and probe.command then
        return (probe.command:match("([^/]+)$") or probe.command)
    end
    return "goldendict"
end

--[[--
Full end to end diagnostic of the GoldenDict path: can we run commands, is
there an executable that actually runs, which command line is used, and does
launching it really leave a running process behind.

`launch` also performs the lookup with a test word.
]]
function Lookup.diagnostics(config, launch)
    local probe = Lookup.probe(config and config.goldendict_path)
    local lines = {}
    lines[#lines + 1] = Lookup.describe(config)

    lines[#lines + 1] = T(_("Shell commands: %1"),
        Lookup.shell_check() and _("working") or _("NOT available"))

    if probe.command_path then
        lines[#lines + 1] = T(_("Resolved path: %1"), probe.command_path)
    end
    local library_path = Lookup.environment("LD_LIBRARY_PATH")
    lines[#lines + 1] = T(_("LD_LIBRARY_PATH: %1"), library_path ~= "" and library_path or _("(unset)"))
    local flatpak = Lookup.flatpak_info()
    lines[#lines + 1] = T(_("Environment: %1"),
        flatpak.in_flatpak and T(_("Flatpak (%1)"), flatpak.app_id or "?") or _("not a Flatpak"))

    local command_line = Lookup.launch_preview(probe, config, "word")

    if probe.command then
        if probe.broken then
            lines[#lines + 1] = T(_("Executable runs: NO — %1"), probe.broken_reason)
            -- Decisive check: the same command without the inherited library
            -- path (KOReader's launcher may export its own).
            local clean_line = Lookup.binary_check(probe.command, 5, true)
            if clean_line ~= "" and not Lookup.looks_like_loader_error(clean_line) then
                lines[#lines + 1] = T(_("It runs without LD_LIBRARY_PATH: %1"), clean_line)
                lines[#lines + 1] = _("The inherited LD_LIBRARY_PATH hides the libraries it needs.")
            elseif probe.flatpak_problem then
                lines[#lines + 1] = _("A host binary cannot run inside the sandbox, whatever its libraries are.")
            else
                lines[#lines + 1] = T(_("It also fails without LD_LIBRARY_PATH: %1"),
                    clean_line ~= "" and clean_line or _("no output"))
                lines[#lines + 1] = T(_("Check it in a terminal: %1"), (probe.command_path or "goldendict") .. " --help")
            end
        elseif probe.host_spawn then
            local host_line = Lookup.binary_check(probe.command, 5, nil, true)
            lines[#lines + 1] = T(_("Executable runs (on the host): %1"),
                host_line ~= "" and host_line or _("no output"))
        elseif probe.url_handler then
            lines[#lines + 1] = T(_("Executable runs: %1"),
                _("not here — the word is handed to the desktop portal instead"))
        else
            local help_line = Lookup.binary_check(probe.command, 5, probe.clean_env)
            lines[#lines + 1] = T(_("Executable runs: %1"),
                help_line ~= "" and help_line or _("no output"))
        end
    end

    if launch then
        local word = "hop-lookup-test"
        if probe.broken then
            lines[#lines + 1] = _("Launched: not attempted — the executable cannot run.")
        elseif probe.host_spawn and Lookup.run_goldendict(config, word) then
            lines[#lines + 1] = T(_("Launched on the host with flatpak-spawn, test word “%1”: yes"), word)
            lines[#lines + 1] = _("The process cannot be checked from inside the sandbox; the word went to the host's GoldenDict.")
        elseif probe.url_handler and Lookup.run_goldendict(config, word) then
            lines[#lines + 1] = T(_("Handed to the desktop portal, test word “%1”: yes"), word)
            lines[#lines + 1] = _("If nothing appears, the host has no handler for goldendict:// — use “flatpak override --user --talk-name=org.freedesktop.Flatpak <app id>” for the direct route, or keep the built-in dictionary.")
        elseif Lookup.run_goldendict(config, word) then
            local process_name = Lookup.process_name(probe)
            -- Give GoldenDict a moment, then check that a process really runs.
            Lookup.command_output({ "sleep", "0.4" })
            local pids = Lookup.running_processes(process_name)
            lines[#lines + 1] = T(_("Launched with test word “%1”: yes"), word)
            lines[#lines + 1] = T(_("GoldenDict process (%1): %2"), process_name,
                pids ~= "" and T(_("running (pid %1)"), pids:gsub("%s+", " ")) or _("none found"))
            if pids == "" then
                lines[#lines + 1] = _("The command was accepted but no GoldenDict process showed up: the executable probably failed to start.")
            else
                lines[#lines + 1] = _("If nothing popped up, check the GoldenDict window mode (popup/main) and its own settings.")
            end
        else
            lines[#lines + 1] = _("Launched: NO — no way to start GoldenDict was found.")
        end
    end

    if command_line then
        lines[#lines + 1] = T(_("Command line: %1"), command_line)
    end
    return table.concat(lines, "\n")
end

--[[--
The command line that will really be used for a lookup (for the diagnostics).
]]
function Lookup.launch_preview(probe, config, word)
    word = word or "word"
    if probe.host_spawn then
        return Lookup.shell_command(Lookup.host_spawn_args(Lookup.process_name(probe),
            config.goldendict_window, word, probe.flavor))
    end
    if probe.command and not probe.broken and not probe.url_route_note then
        return Lookup.goldendict_command(probe.command, config.goldendict_window, word,
            probe.flavor or "ng", probe.clean_env)
    end
    if probe.flatpak then
        return Lookup.shell_command(Lookup.flatpak_args(config.goldendict_window, word, "ng"))
    end
    if probe.url_handler then
        local opener = Lookup.command_exists("xdg-open") and "xdg-open" or "gio"
        local args = { opener }
        if opener == "gio" then
            args[#args + 1] = "open"
        end
        args[#args + 1] = "goldendict://" .. Lookup.url_encode(word)
        return Lookup.shell_command(args)
    end
end

--[[--
Human readable description of the current GoldenDict setup, for the menu.
]]
function Lookup.describe(config)
    local probe = Lookup.probe(config and config.goldendict_path)
    local lines = {}
    lines[#lines + 1] = T(_("Backend: %1"), config.backend)
    lines[#lines + 1] = T(_("Mode: %1"), config.goldendict_window)
    lines[#lines + 1] = T(_("Configured path: %1"), config.goldendict_path)
    if probe.command then
        lines[#lines + 1] = T(_("Executable found: %1"), probe.command)
        lines[#lines + 1] = T(_("Variant: %1"), probe.flavor == "ng"
            and _("GoldenDict-ng (popup and main window can be forced)")
            or _("original GoldenDict (it decides which window to use)"))
        if probe.evidence then
            lines[#lines + 1] = T(_("Detected by: %1"), probe.evidence)
        end
        if probe.assumed then
            -- The automatic detection gave up: run the slow --help check now,
            -- as this is an explicit diagnostic.
            local flavor, evidence = Lookup.detect_flavor(probe.command, 8)
            lines[#lines + 1] = T(_("--help check: %1 (%2)"),
                flavor or _("inconclusive"), tostring(evidence))
        end
        local preview = Lookup.launch_preview(probe, config, "word")
        lines[#lines + 1] = T(_("Command: %1"),
            preview or _("none — GoldenDict cannot be started from here"))
    elseif probe.flatpak then
        lines[#lines + 1] = T(_("Flatpak found: %1"), Lookup.flatpak_app_id)
        lines[#lines + 1] = T(_("Command: %1"),
            Lookup.shell_command(Lookup.flatpak_args(config.goldendict_window, "word", "ng")))
    elseif probe.device_dict then
        lines[#lines + 1] = T(_("Application found: %1"), probe.device_dict[2] or probe.device_dict[4])
    elseif probe.url_handler then
        lines[#lines + 1] = T(_("URL handler found: %1"),
            "goldendict://word?target=" .. (config.goldendict_window == "popup" and "popup" or "main"))
    else
        lines[#lines + 1] = _("GoldenDict was not found.")
        lines[#lines + 1] = T(_("Looked for the configured path and for: %1"),
            table.concat(Lookup.candidate_commands, ", "))
        lines[#lines + 1] = _("Set the path of the executable in “GoldenDict path”, or install GoldenDict.")
    end
    if probe.env_reason then
        lines[#lines + 1] = T(_("Note: %1, so it is started without LD_LIBRARY_PATH."), probe.env_reason)
    end
    if probe.host_spawn_note then
        lines[#lines + 1] = probe.host_spawn_note
    elseif probe.url_route_note then
        lines[#lines + 1] = probe.url_route_note
    end
    if probe.broken then
        lines[#lines + 1] = T(_("PROBLEM: %1."), probe.broken_reason)
        if probe.flatpak_problem then
            local flatpak = Lookup.flatpak_info()
            lines[#lines + 1] = T(_("KOReader runs as a Flatpak (%1): it can see the host's GoldenDict but cannot start it from inside the sandbox."),
                flatpak.app_id or "?")
            lines[#lines + 1] = _("Either keep using the built-in dictionary, run KOReader outside Flatpak, or allow host commands with:")
            lines[#lines + 1] = T(_("flatpak override --user --talk-name=org.freedesktop.Flatpak %1"),
                flatpak.app_id or "<app id>")
        else
            lines[#lines + 1] = _("Install the missing libraries (or reinstall GoldenDict), then check again.")
        end
    end
    if config.backend == "auto" and not probe.available then
        lines[#lines + 1] = _("With the “auto” backend the built-in dictionary is used instead.")
    end
    return table.concat(lines, "\n")
end

return Lookup
