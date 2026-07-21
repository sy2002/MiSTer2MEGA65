#!/usr/bin/env python3
"""
make_release.py - Package a MiSTer2MEGA65 core release.

The release workflow is shared across M2M cores. Core-specific release
metadata lives in CORE/release.toml, with optional custom hooks in
CORE/release_hooks.py. The script still assumes the standard M2M repository
layout: CORE/vhdl/config.vhd, M2M/tools/make_config.sh, and per-board Vivado
outputs below CORE/CORE-R*.runs/impl_1/.

By default the script prints only the final release summary; pass --verbatim
to print the full step-by-step log.
"""

from __future__ import annotations

import argparse
import ast
import datetime as _dt
import importlib.util
import os
import re
import shlex
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, NoReturn, Optional

try:
    import tomllib
except ModuleNotFoundError:
    tomllib = None


# ---------------------------------------------------------------------------
# Framework defaults
# ---------------------------------------------------------------------------

BOARD_REVS = ("R3", "R4", "R5", "R6")
RELEASE_CONFIG = Path("CORE") / "release.toml"
RELEASE_HOOKS = Path("CORE") / "release_hooks.py"
CONFIG_VHD = Path("CORE") / "vhdl" / "config.vhd"
MAKE_CONFIG_SH = Path("M2M") / "tools" / "make_config.sh"
VERSIONS_MD = Path("VERSIONS.md")
INOFFICIAL_MD = Path("doc") / "inofficial.md"

# Regex for the four accepted version conventions.
RE_MAJOR = re.compile(r"^V(\d+)$")
RE_MINOR = re.compile(r"^V(\d+)\.(\d+)$")
RE_ALPHA = re.compile(r"^WIP-V(\d+)-A(\d+)(?:X([1-9]\d*))?$")
RE_BETA = re.compile(r"^WIP-V(\d+)-B(\d+)(?:X([1-9]\d*))?$")

POLICIES = ("required", "optional", "skip")
VERSION_CHECKS = ("core_version_constant", "regex", "none")


# ---------------------------------------------------------------------------
# Colored output (cross-platform)
# ---------------------------------------------------------------------------

def _supports_color() -> bool:
    if os.environ.get("NO_COLOR"):
        return False
    if not sys.stdout.isatty():
        return False
    if sys.platform == "win32":
        # Try to enable VT mode on Windows 10+. If it fails, fall back to no color.
        try:
            import ctypes
            kernel32 = ctypes.windll.kernel32
            handle = kernel32.GetStdHandle(-11)
            mode = ctypes.c_ulong()
            if not kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
                return False
            kernel32.SetConsoleMode(handle, mode.value | 0x0004)
            return True
        except Exception:
            return False
    return True


_COLOR = _supports_color()
_VERBATIM = False


def _c(code: str, text: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _COLOR else text


def set_verbatim(enabled: bool) -> None:
    global _VERBATIM
    _VERBATIM = enabled


def info(msg: str) -> None:
    if _VERBATIM:
        print(f"{_c('36', '[INFO]')} {msg}")


def ok(msg: str) -> None:
    if _VERBATIM:
        print(f"{_c('32', '[ OK ]')} {msg}")


_WARNINGS: list[str] = []


def warn(msg: str) -> None:
    _WARNINGS.append(msg)
    if _VERBATIM:
        print(f"{_c('33', '[WARN]')} {msg}")


def err(msg: str) -> None:
    print(f"{_c('31;1', '[FAIL]')} {msg}", file=sys.stderr)


def die(msg: str, code: int = 1) -> NoReturn:
    err(msg)
    sys.exit(code)


# ---------------------------------------------------------------------------
# Release configuration
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class ReleaseConfig:
    file_base: str
    display_name: str
    boards: tuple[str, ...]
    version_check: str
    version_file: Path
    version_constant: str
    version_pattern: str
    bit2core_tail: str
    coretool_flags: str
    coretool_caps: str
    shell_config_enabled: bool
    shell_config_filename: str
    versions_md_policy: str
    inofficial_md_policy: str
    cleanup_stale_files: tuple[str, ...]


@dataclass(frozen=True)
class HookContext:
    repo: Path
    out: Path
    version: str
    kind: str
    targets: tuple[str, ...]
    config: ReleaseConfig
    force: bool
    ignore: bool
    verbatim: bool

    def warn(self, msg: str) -> None:
        warn(msg)

    def die(self, msg: str, code: int = 1) -> NoReturn:
        die(msg, code)

    def copy_preserving_timestamps(self, src: Path, dst: Path) -> None:
        copy_preserving_timestamps(src, dst)


def _strip_toml_comment(line: str) -> str:
    in_string = False
    escaped = False
    out = []
    for ch in line:
        if escaped:
            out.append(ch)
            escaped = False
            continue
        if ch == "\\" and in_string:
            out.append(ch)
            escaped = True
            continue
        if ch == '"':
            in_string = not in_string
            out.append(ch)
            continue
        if ch == "#" and not in_string:
            break
        out.append(ch)
    return "".join(out).strip()


def _load_simple_toml(path: Path) -> dict[str, Any]:
    """Fallback parser for the simple TOML subset used by CORE/release.toml."""
    data: dict[str, Any] = {}
    section: Optional[dict[str, Any]] = None

    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = _strip_toml_comment(raw)
        if not line:
            continue
        if line.startswith("[") and line.endswith("]"):
            name = line[1:-1].strip()
            if not name or "." in name:
                die(f"{path}: unsupported TOML section on line {lineno}: {raw}")
            section = data.setdefault(name, {})
            if not isinstance(section, dict):
                die(f"{path}: duplicate non-table key on line {lineno}: {raw}")
            continue
        if section is None:
            die(f"{path}: key outside a section on line {lineno}: {raw}")
        if "=" not in line:
            die(f"{path}: expected key = value on line {lineno}: {raw}")

        key, value = [part.strip() for part in line.split("=", 1)]
        if not key:
            die(f"{path}: empty key on line {lineno}: {raw}")
        if value in ("true", "false"):
            parsed: Any = value == "true"
        else:
            try:
                parsed = ast.literal_eval(value)
            except (SyntaxError, ValueError) as exc:
                die(f"{path}: unsupported TOML value on line {lineno}: {raw}\n"
                    f"  {exc}")
        section[key] = parsed
    return data


def _load_toml(path: Path) -> dict[str, Any]:
    if tomllib is not None:
        with path.open("rb") as f:
            return tomllib.load(f)
    return _load_simple_toml(path)


def _section(data: dict[str, Any], name: str) -> dict[str, Any]:
    value = data.get(name, {})
    if not isinstance(value, dict):
        die(f"{RELEASE_CONFIG}: section [{name}] must be a table.")
    return value


def _get_str(section: dict[str, Any], key: str, default: Optional[str] = None,
             required: bool = False) -> str:
    if key not in section:
        if required:
            die(f"{RELEASE_CONFIG}: missing required key '{key}'.")
        return "" if default is None else default
    value = section[key]
    if not isinstance(value, str):
        die(f"{RELEASE_CONFIG}: key '{key}' must be a string.")
    return value


def _get_bool(section: dict[str, Any], key: str, default: bool) -> bool:
    if key not in section:
        return default
    value = section[key]
    if not isinstance(value, bool):
        die(f"{RELEASE_CONFIG}: key '{key}' must be true or false.")
    return value


def _get_string_list(section: dict[str, Any], key: str,
                     default: tuple[str, ...]) -> tuple[str, ...]:
    if key not in section:
        return default
    value = section[key]
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        die(f"{RELEASE_CONFIG}: key '{key}' must be a list of strings.")
    return tuple(value)


def _get_policy(section: dict[str, Any], key: str, default: str) -> str:
    value = _get_str(section, key, default)
    if value not in POLICIES:
        die(f"{RELEASE_CONFIG}: key '{key}' must be one of "
            f"{', '.join(POLICIES)}.")
    return value


def load_release_config(repo: Path) -> ReleaseConfig:
    path = repo / RELEASE_CONFIG
    if not path.is_file():
        die(f"{RELEASE_CONFIG} not found. Add a core release configuration "
            f"file before running this generic release tool.")

    data = _load_toml(path)
    core = _section(data, "core")
    version = _section(data, "version")
    cor = _section(data, "cor")
    shell_config = _section(data, "shell_config")
    release_notes = _section(data, "release_notes")
    alpha = _section(data, "alpha")
    cleanup = _section(data, "cleanup")

    file_base = _get_str(core, "file_base", required=True)
    display_name = _get_str(core, "display_name", required=True)
    boards = _get_string_list(core, "boards", BOARD_REVS)
    invalid_boards = [board for board in boards if board not in BOARD_REVS]
    if invalid_boards:
        die(f"{RELEASE_CONFIG}: unsupported board revision(s): "
            f"{', '.join(invalid_boards)}. Valid boards: {', '.join(BOARD_REVS)}.")

    version_check = _get_str(version, "check", "core_version_constant")
    if version_check not in VERSION_CHECKS:
        die(f"{RELEASE_CONFIG}: version.check must be one of "
            f"{', '.join(VERSION_CHECKS)}.")

    return ReleaseConfig(
        file_base=file_base,
        display_name=display_name,
        boards=tuple(board for board in BOARD_REVS if board in boards),
        version_check=version_check,
        version_file=Path(_get_str(version, "file", str(CONFIG_VHD))),
        version_constant=_get_str(version, "constant", "CORE_VERSION"),
        version_pattern=_get_str(version, "pattern", ""),
        bit2core_tail=_get_str(cor, "bit2core_tail", ""),
        coretool_flags=_get_str(cor, "coretool_flags", ""),
        coretool_caps=_get_str(cor, "coretool_caps", ""),
        shell_config_enabled=_get_bool(shell_config, "enabled", True),
        shell_config_filename=_get_str(shell_config, "filename", required=True),
        versions_md_policy=_get_policy(release_notes, "versions_md", "required"),
        inofficial_md_policy=_get_policy(alpha, "inofficial_md", "required"),
        cleanup_stale_files=_get_string_list(cleanup, "stale_files", ()),
    )


def format_pattern(pattern: str, cfg: ReleaseConfig, version: str,
                   rev: Optional[str] = None) -> str:
    values = {
        "file_base": cfg.file_base,
        "display_name": cfg.display_name,
        "version": version,
        "rev": rev or "",
        "rev_lower": (rev or "").lower(),
    }
    try:
        return pattern.format(**values)
    except KeyError as exc:
        die(f"{RELEASE_CONFIG}: unknown format key {{{exc.args[0]}}} in "
            f"pattern {pattern!r}.")


# ---------------------------------------------------------------------------
# Hooks
# ---------------------------------------------------------------------------

def load_release_hooks(repo: Path):
    path = repo / RELEASE_HOOKS
    if not path.is_file():
        return None

    spec = importlib.util.spec_from_file_location("core_release_hooks", path)
    if spec is None or spec.loader is None:
        die(f"Could not import {path.relative_to(repo)}.")
    module = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(module)
    except Exception as exc:
        die(f"Importing {path.relative_to(repo)} failed: {exc}")
    info(f"Loaded release hooks from {path.relative_to(repo)}.")
    return module


def run_hook(hooks, name: str, ctx: HookContext):
    if hooks is None:
        return None
    func = getattr(hooks, name, None)
    if func is None:
        return None
    if not callable(func):
        die(f"{RELEASE_HOOKS}: hook '{name}' exists but is not callable.")
    try:
        return func(ctx)
    except Exception as exc:
        die(f"{RELEASE_HOOKS}: hook '{name}' failed: {exc}")


# ---------------------------------------------------------------------------
# Version parsing
# ---------------------------------------------------------------------------

def classify_version(name: str) -> str:
    """Return one of 'major', 'minor', 'alpha', 'beta' or raise ValueError."""
    if RE_MAJOR.match(name):
        return "major"
    if RE_MINOR.match(name):
        return "minor"
    if RE_ALPHA.match(name):
        return "alpha"
    if RE_BETA.match(name):
        return "beta"
    raise ValueError(
        f"'{name}' is not a valid version. Expected one of:\n"
        f"  Major  : V<n>          (e.g. V6)\n"
        f"  Minor  : V<n>.<m>      (e.g. V6.1)\n"
        f"  Alpha  : WIP-V<n>-A<m>[X<k>] (e.g. WIP-V6-A6, WIP-V6-A13X1)\n"
        f"  Beta   : WIP-V<n>-B<m>[X<k>] (e.g. WIP-V6-B1, WIP-V6-B2X1)\n"
        f"  Or pass -i / --ignore for an ad-hoc name that is already present "
        f"in config.vhd."
    )


# ---------------------------------------------------------------------------
# Repo discovery
# ---------------------------------------------------------------------------

def find_repo_root() -> Path:
    """The script lives at <repo>/make_release.py."""
    here = Path(__file__).resolve()
    root = here.parent
    if not (root / "CORE").is_dir():
        die(f"Cannot locate repository root from {here} "
            f"(expected a CORE directory under {root})")
    return root


# ---------------------------------------------------------------------------
# config.vhd check
# ---------------------------------------------------------------------------

def _version_constant_re(constant_name: str) -> re.Pattern[str]:
    return re.compile(
        r"constant\s+" + re.escape(constant_name) +
        r'\s*:\s*string\s*:=\s*"([^"]+)"\s*;'
    )


def check_config_vhd(repo: Path, cfg: ReleaseConfig, version: str) -> None:
    """Confirm the configured version source matches the CLI version."""
    if cfg.version_check == "none":
        warn("No version check configured; release name was not verified "
             f"against {cfg.version_file}.")
        return

    path = repo / cfg.version_file
    if not path.is_file():
        die(f"{cfg.version_file} not found.")
    text = path.read_text(encoding="utf-8", errors="replace")

    if cfg.version_check == "core_version_constant":
        regex = _version_constant_re(cfg.version_constant)
        description = (
            f"`constant {cfg.version_constant} : string := \"...\";`"
        )
    elif cfg.version_check == "regex":
        if not cfg.version_pattern:
            die(f"{RELEASE_CONFIG}: version.pattern is required when "
                f"version.check = \"regex\".")
        try:
            regex = re.compile(cfg.version_pattern)
        except re.error as exc:
            die(f"{RELEASE_CONFIG}: invalid version.pattern: {exc}")
        description = f"version regex {cfg.version_pattern!r}"
    else:
        raise ValueError(f"Unsupported version check: {cfg.version_check}")

    matches = regex.findall(text)
    if not matches:
        die(f"Could not find {description} in {cfg.version_file}. "
            f"Either add it or set version.check = \"none\" in "
            f"{RELEASE_CONFIG}.")
    if len(matches) > 1:
        die(f"Found {len(matches)} version assignments in {cfg.version_file}; "
            f"expected exactly one. Values: "
            f"{', '.join(repr(m) for m in matches)}.")

    found = matches[0]
    if isinstance(found, tuple):
        found = found[0]
    if found != version:
        die(f"Version mismatch: command line says '{version}' but "
            f"{cfg.version_file} has '{found}'. Update the core version "
            f"source to '{version}' or call the script with '{found}'.")
    ok(f"Version source in {cfg.version_file} matches command line: "
       f"'{version}'.")


# ---------------------------------------------------------------------------
# Alpha/beta-release checks
# ---------------------------------------------------------------------------

def check_inofficial_md(repo: Path, version: str, policy: str) -> Optional[str]:
    """Verify the alpha/beta is listed in doc/inofficial.md and return its commit."""
    if policy == "skip":
        info("Alpha/beta release row check disabled by release.toml.")
        return None

    path = repo / INOFFICIAL_MD
    if not path.is_file():
        msg = f"{INOFFICIAL_MD} not found."
        if policy == "optional":
            warn(msg + " Skipping alpha/beta release row check.")
            return None
        die(msg)

    # Lines look like:
    # | WIP-V6-A6     | 04/21/26 | 4975181 | Improve initial RAM contents ...
    row_re = re.compile(
        r"^\|\s*" + re.escape(version) + r"\s*\|"
        r"\s*([0-9/]+)\s*\|"
        r"\s*([0-9a-fA-F]+)\s*\|"
        r"\s*(.*?)\s*$"
    )

    for line in path.read_text(encoding="utf-8").splitlines():
        m = row_re.match(line)
        if m:
            date, commit, comment = m.groups()
            ok(f"Found '{version}' in {INOFFICIAL_MD} "
               f"(date {date}, commit {commit}).")
            return commit

    msg = f"Alpha/beta release '{version}' is not listed in {INOFFICIAL_MD}."
    if policy == "optional":
        warn(msg + " Skipping git release-row check.")
        return None
    die(msg + " Add a row before building the release.")


def check_git_commit(repo: Path, commit: str, version: str) -> None:
    try:
        result = subprocess.run(
            ["git", "-C", str(repo), "rev-parse", "--verify", f"{commit}^{{commit}}"],
            capture_output=True, text=True, check=False,
        )
    except FileNotFoundError:
        die("git executable not found in PATH (needed for alpha/beta-release verification).")

    if result.returncode != 0:
        die(f"Commit '{commit}' from {INOFFICIAL_MD} (row '{version}') "
            f"is not a valid git commit in this repository.\n"
            f"  git said: {result.stderr.strip()}")
    full = result.stdout.strip()
    ok(f"Commit '{commit}' resolves to {full[:12]} in git.")


# ---------------------------------------------------------------------------
# Target selection
# ---------------------------------------------------------------------------

def parse_targets(spec: str, cfg: ReleaseConfig) -> tuple[str, ...]:
    """Parse a target spec like 'R3,R5' / 'r3+r6' / 'R4 R5'."""
    tokens = [t for t in re.split(r"[\s,+/;]+", spec.strip()) if t]
    if not tokens:
        die("Target list is empty. Use e.g. 'R3,R6' or omit the argument "
            "to build all configured targets.")
    chosen: list[str] = []
    for tok in tokens:
        norm = tok.upper()
        if norm not in cfg.boards:
            die(f"Unknown target '{tok}'. Valid targets: "
                f"{', '.join(cfg.boards)}. Separate multiple with comma "
                f"(e.g. R3,R5).")
        if norm not in chosen:
            chosen.append(norm)
    return tuple(r for r in cfg.boards if r in chosen)


def warn_if_stale(repo: Path, targets: tuple[str, ...]) -> None:
    """Warn for any bitstream whose mtime is older than today (local time)."""
    today_start = _dt.datetime.combine(_dt.date.today(), _dt.time.min).timestamp()
    stale = []
    for rev in targets:
        p = source_bit_path(repo, rev)
        if not p.is_file():
            continue
        if p.stat().st_mtime < today_start:
            mtime = _dt.datetime.fromtimestamp(p.stat().st_mtime)
            stale.append((rev, mtime))
    if stale:
        warn("Some bitstreams were not built today - you may be packaging "
             "an outdated release:")
        for rev, mtime in stale:
            warn(f"  {rev}: {source_bit_path(repo, rev).name} last built "
                 f"{mtime.strftime('%Y-%m-%d %H:%M:%S')}")


# ---------------------------------------------------------------------------
# coretool / bit2core / bitstreams
# ---------------------------------------------------------------------------

OUTPUT_SEPARATE = "separate"
OUTPUT_MERGED_PYTHON = "merged-python"


@dataclass(frozen=True)
class CoreFileTool:
    """External tool used to produce .cor files from .bit files."""

    name: str
    command_prefix: tuple[str, ...]
    source: str
    output_mode: str


def _format_command_prefix(prefix: tuple[str, ...]) -> str:
    return " ".join(_quote(part) for part in prefix)


def _normalize_command_prefix(parts: list[str]) -> tuple[str, ...]:
    """Validate and normalize a command prefix parsed from PATH or an alias."""
    if not parts:
        return ()

    expanded = [os.path.expandvars(os.path.expanduser(part)) for part in parts]
    exe = expanded[0]
    if os.sep in exe:
        if not (Path(exe).is_file() and os.access(exe, os.X_OK)):
            return ()
    else:
        resolved = shutil.which(exe)
        if not resolved:
            return ()
        expanded[0] = resolved

    return tuple(expanded)


def _parse_shell_type_output(tool_name: str, out: str) -> tuple[str, ...]:
    """Parse bash/zsh-ish `type` output into a runnable command prefix."""
    if "is a function" in out:
        return ()

    alias_patterns = (
        rf"^{re.escape(tool_name)} is aliased to [`'](.+)'$",
        rf"^{re.escape(tool_name)}: aliased to (.+)$",
    )
    path_patterns = (
        rf"^{re.escape(tool_name)} is (~?/.*)$",
        rf"^{re.escape(tool_name)}: (~?/.*)$",
    )

    for raw_line in out.splitlines():
        line = raw_line.strip()
        for pattern in alias_patterns:
            m = re.match(pattern, line)
            if m:
                try:
                    return _normalize_command_prefix(shlex.split(m.group(1)))
                except ValueError:
                    return ()
        for pattern in path_patterns:
            m = re.match(pattern, line)
            if m:
                return _normalize_command_prefix([m.group(1)])

    return ()


def _resolve_tool_via_shell_rc(tool_name: str) -> tuple[str, ...]:
    """Resolve a tool from shell startup files if it is not on PATH."""
    if os.name == "nt":
        return ()

    snippet = (
        "shopt -s expand_aliases 2>/dev/null; "
        "for rc in ~/.bash_profile ~/.bashrc ~/.zshrc ~/.zprofile ~/.profile; do "
        "  [ -f \"$rc\" ] && . \"$rc\" >/dev/null 2>&1; "
        "done; "
        f"type {shlex.quote(tool_name)} 2>/dev/null"
    )

    try:
        result = subprocess.run(
            ["/bin/bash", "-c", snippet],
            capture_output=True, text=True, timeout=10,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return ()

    out = (result.stdout or "") + "\n" + (result.stderr or "")
    return _parse_shell_type_output(tool_name, out)


def _tool_output_mode(tool_name: str) -> str:
    if tool_name == "coretool":
        return OUTPUT_MERGED_PYTHON
    if tool_name == "bit2core":
        return OUTPUT_SEPARATE
    raise ValueError(f"Unsupported core-file tool: {tool_name}")


def _find_core_file_tool(tool_name: str):
    path = shutil.which(tool_name)
    if path:
        return CoreFileTool(tool_name, (path,), "PATH", _tool_output_mode(tool_name))

    prefix = _resolve_tool_via_shell_rc(tool_name)
    if prefix:
        return CoreFileTool(tool_name, prefix, "shell startup files",
                            _tool_output_mode(tool_name))

    return None


def check_core_file_tool() -> CoreFileTool:
    tools = []
    for tool_name in ("coretool", "bit2core"):
        tool = _find_core_file_tool(tool_name)
        if tool:
            tools.append(tool)
            ok(f"Found {tool.name} via {tool.source}: "
               f"{_format_command_prefix(tool.command_prefix)}.")

    if not tools:
        die("'coretool' or 'bit2core' not found. Neither tool is on PATH nor "
            "resolvable from bash/zsh startup files. Install mega65-tools or "
            "add coretool/bit2core to your PATH/aliases and try again.")

    selected = next((tool for tool in tools if tool.name == "coretool"), tools[0])
    if selected.name == "coretool" and any(tool.name == "bit2core" for tool in tools):
        info("Both coretool and bit2core are available; using coretool.")
    else:
        info(f"Using {selected.name} to generate .cor files.")
    return selected


def board_to_machine(rev: str) -> str:
    """coretool target / bit2core machine argument: 'mega65rN'."""
    return f"mega65r{rev[1:].lower()}"


def source_bit_path(repo: Path, rev: str) -> Path:
    return repo / "CORE" / f"CORE-{rev}.runs" / "impl_1" / f"mega65_{rev.lower()}.bit"


def dest_bit_name(cfg: ReleaseConfig, version: str, rev: str) -> str:
    return f"{cfg.file_base}-{version}-{rev}.bit"


def dest_cor_name(cfg: ReleaseConfig, version: str, rev: str) -> str:
    return f"{cfg.file_base}-{version}-{rev}.cor"


def copy_preserving_timestamps(src: Path, dst: Path) -> None:
    shutil.copy2(src, dst)


def generate_shell_config(repo: Path, dst: Path) -> None:
    """Run M2M/tools/make_config.sh to produce the QNICE Shell persistence file."""
    bash = shutil.which("bash")
    if not bash:
        die("'bash' not found in PATH. Cannot run make_config.sh to generate "
            "the config file. Install bash (Git Bash on Windows) and retry.")

    tools_dir = repo / "M2M" / "tools"
    script = repo / MAKE_CONFIG_SH
    if not script.is_file():
        die(f"{MAKE_CONFIG_SH} not found.")

    cmd = [bash, str(script), str(dst), "auto"]
    info(f"Running: bash {MAKE_CONFIG_SH} {dst.name} auto")
    result = subprocess.run(cmd, cwd=str(tools_dir),
                            capture_output=True, text=True)
    if _VERBATIM or result.returncode != 0:
        for stream in (result.stdout, result.stderr):
            _print_tool_output(stream)
    if result.returncode != 0:
        die(f"make_config.sh failed (exit code {result.returncode}).")
    if not dst.is_file():
        die(f"make_config.sh did not produce {dst}.")


def copy_policy_file(repo: Path, out: Path, rel_path: Path, policy: str):
    if policy == "skip":
        info(f"Skipping {rel_path}; policy is 'skip'.")
        return None

    src = repo / rel_path
    if not src.is_file():
        msg = f"{rel_path} not found in repository."
        if policy == "optional":
            warn(msg + " Skipping.")
            return None
        die(msg)

    dst = out / src.name
    copy_preserving_timestamps(src, dst)
    return dst


def _build_coretool_args(cfg: ReleaseConfig, machine: str, src_bit: Path,
                         version: str, dst_cor: Path,
                         overwrite: bool) -> tuple[tuple[str, ...], tuple[str, ...]]:
    args = [
        "-B", str(dst_cor),
        "--bit", str(src_bit),
        "--target", machine,
        "--bit-name", cfg.display_name,
        "--bit-version", version,
    ]
    display = [
        "-B", _quote(str(dst_cor)),
        "--bit", _quote(str(src_bit)),
        "--target", machine,
        "--bit-name", _force_quote(cfg.display_name),
        "--bit-version", _force_quote(version),
    ]
    if cfg.coretool_flags:
        args.extend(["--flags", cfg.coretool_flags])
        display.extend(["--flags", _quote(cfg.coretool_flags)])
    if cfg.coretool_caps:
        args.extend(["--caps", cfg.coretool_caps])
        display.extend(["--caps", _quote(cfg.coretool_caps)])
    if overwrite:
        args.insert(0, "--force")
        display.insert(0, "--force")
    return tuple(args), tuple(display)


def _build_bit2core_args(cfg: ReleaseConfig, machine: str, src_bit: Path,
                         version: str, dst_cor: Path) -> tuple[tuple[str, ...],
                                                               tuple[str, ...]]:
    args = [
        machine, str(src_bit),
        cfg.display_name, version,
        str(dst_cor),
    ]
    display = (
        [machine, _quote(str(src_bit))]
        + [_force_quote(cfg.display_name), _force_quote(version)]
        + [_quote(str(dst_cor))]
    )
    if cfg.bit2core_tail:
        args.append(cfg.bit2core_tail)
        display.append(_quote(cfg.bit2core_tail))
    return tuple(args), tuple(display)


def _build_core_file_command(cfg: ReleaseConfig, tool: CoreFileTool,
                             machine: str, src_bit: Path, version: str,
                             dst_cor: Path, overwrite: bool) -> tuple[tuple[str, ...],
                                                                       tuple[str, ...]]:
    if tool.name == "coretool":
        args, display_args = _build_coretool_args(
            cfg, machine, src_bit, version, dst_cor, overwrite
        )
    elif tool.name == "bit2core":
        args, display_args = _build_bit2core_args(
            cfg, machine, src_bit, version, dst_cor
        )
    else:
        raise ValueError(f"Unsupported core-file tool: {tool.name}")

    cmd = tuple(tool.command_prefix) + args
    display = tuple(_quote(part) for part in tool.command_prefix) + display_args
    return cmd, display


def _print_tool_output(stream: str, force: bool = False) -> None:
    if (_VERBATIM or force) and stream and stream.strip():
        for line in stream.rstrip().splitlines():
            print(f"        {line}")


def _run_separate_capture(tool: CoreFileTool, cmd: tuple[str, ...],
                          machine: str) -> None:
    # bit2core emits Xilinx-header validation lines on stdout and the
    # WARNING/INFO/"Core file written" lines on stderr. Capture them
    # separately and print stdout first, then stderr, matching the order
    # bit2core produces in an interactive terminal. A merged-stream pipe would
    # reorder them due to stdout becoming block-buffered when not connected to
    # a TTY.
    result = subprocess.run(cmd, capture_output=True, text=True)
    force_output = result.returncode != 0
    for stream in (result.stdout, result.stderr):
        _print_tool_output(stream, force=force_output)
    if result.returncode != 0:
        die(f"{tool.name} failed for {machine} (exit code {result.returncode}).")


def _run_python_merged_capture(tool: CoreFileTool, cmd: tuple[str, ...],
                               machine: str) -> None:
    # coretool is a Python program. PYTHONUNBUFFERED keeps stdout/stderr write
    # order stable when both streams are merged into one captured pipe.
    env = os.environ.copy()
    env["PYTHONUNBUFFERED"] = "1"
    result = subprocess.run(cmd, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, env=env)
    _print_tool_output(result.stdout, force=result.returncode != 0)
    if result.returncode != 0:
        die(f"{tool.name} failed for {machine} (exit code {result.returncode}).")


def run_core_file_tool(cfg: ReleaseConfig, tool: CoreFileTool, machine: str,
                       src_bit: Path, version: str, dst_cor: Path,
                       overwrite: bool) -> None:
    cmd, display = _build_core_file_command(
        cfg, tool, machine, src_bit, version, dst_cor, overwrite
    )
    info(f"Running ({tool.name}): " + " ".join(display))
    try:
        if tool.output_mode == OUTPUT_SEPARATE:
            _run_separate_capture(tool, cmd, machine)
        elif tool.output_mode == OUTPUT_MERGED_PYTHON:
            _run_python_merged_capture(tool, cmd, machine)
        else:
            raise ValueError(f"Unsupported output mode: {tool.output_mode}")
    except FileNotFoundError:
        die(f"{tool.name} executable not found while running: "
            f"{_format_command_prefix(tool.command_prefix)}")


def _quote(arg: str) -> str:
    if " " in arg or "+" in arg or "=" in arg or "," in arg:
        return f'"{arg}"'
    return arg


def _force_quote(arg: str) -> str:
    return f'"{arg}"'


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def build_parser(cfg: ReleaseConfig) -> argparse.ArgumentParser:
    release_folder = f"{cfg.file_base}-<version>"
    config_example = (
        format_pattern(cfg.shell_config_filename, cfg, "V1.1")
        if cfg.shell_config_enabled else "no shell config file"
    )

    parser = argparse.ArgumentParser(
        prog="make_release.py",
        description=f"Package releases for {cfg.display_name}: copy configured "
                    f"board bitstreams, produce .cor files via coretool or "
                    f"bit2core, generate the Shell config file if enabled, "
                    f"and copy release notes according to CORE/release.toml.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Version conventions:\n"
            "  Major  : V<n>          (e.g. V1)\n"
            "  Minor  : V<n>.<m>      (e.g. V1.1)\n"
            "  Alpha  : WIP-V<n>-A<m>[X<k>] (e.g. WIP-V1-A6, WIP-V1-A13X1)\n"
            "  Beta   : WIP-V<n>-B<m>[X<k>] (e.g. WIP-V1-B1, WIP-V1-B2X1)\n"
            "  Ignore : pass -i / --ignore to package an ad-hoc version name.\n"
            "           Unless version.check is 'none', the name still must\n"
            "           match the configured version source.\n\n"
            "Target selection:\n"
            f"  Omit the third argument to build all configured boards "
            f"({', '.join(cfg.boards)}).\n"
            "  Otherwise pass a comma-separated list, e.g. 'R3,R6' or 'R4,R5'.\n"
            "  Other accepted separators: + / ; whitespace. Case-insensitive.\n\n"
            "Output layout:\n"
            "  The second argument is a parent folder. The script creates\n"
            f"  a subfolder named {release_folder} in it and places the\n"
            "  per-board .bit and .cor files there. Example config artifact:\n"
            f"    {config_example}\n"
            "  If the release subfolder already exists and is non-empty, the\n"
            "  script aborts unless -f / --force is passed.\n\n"
            "Examples:\n"
            "  make_release.py V1 ~/Desktop\n"
            "  make_release.py WIP-V1-A6 /tmp/builds\n"
            "  make_release.py WIP-V1-A13X1 /tmp/builds R6\n"
            "  make_release.py WIP-V1-B1 /tmp/builds\n"
            "  make_release.py A15test1 /tmp/builds R6 --ignore\n"
            "  make_release.py V1.1 ./out R3,R6\n"
            "  make_release.py V1.1 ./out R3,R6 --force\n"
            "  make_release.py V1.1 ./out R6 --verbatim\n"
        ),
    )
    parser.add_argument("version",
                        help="Release name, e.g. V1, V1.1, WIP-V1-A6 or "
                             "WIP-V1-B1")
    parser.add_argument("output_folder",
                        help=f"Parent folder. The script creates a subfolder "
                             f"named {cfg.file_base}-<version> inside it and "
                             f"places all release files there. The parent is "
                             f"created if missing; the subfolder must not "
                             f"already exist and be non-empty (use --force "
                             f"to overwrite).")
    parser.add_argument("targets", nargs="?", default=None,
                        help="Optional comma-separated subset of boards to "
                             f"build, e.g. 'R3,R6'. Defaults to all "
                             f"configured boards ({','.join(cfg.boards)}).")
    parser.add_argument("-f", "--force", action="store_true",
                        help="Overwrite an existing, non-empty release "
                             "subfolder. Without this flag, the script "
                             "refuses to clobber an existing release.")
    parser.add_argument("-i", "--ignore", action="store_true",
                        help="Ignore the standard version-name grammar and "
                             "skip the alpha/beta-release row check. The version "
                             "string is still checked against the configured "
                             "version source unless version.check is 'none'.")
    parser.add_argument("-v", "--verbatim", action="store_true",
                        help="Print the full step-by-step output, including "
                             "external tool commands and captured tool output. "
                             "By default only the final release summary is "
                             "printed.")
    return parser


def main() -> None:
    repo = find_repo_root()
    cfg = load_release_config(repo)
    parser = build_parser(cfg)
    args = parser.parse_args()
    set_verbatim(args.verbatim)

    hooks = load_release_hooks(repo)

    # 1) Validate version format up front.
    if args.ignore:
        kind = "ignored"
        info("Version grammar ignored; configured version source will still "
             "be checked.")
    else:
        try:
            kind = classify_version(args.version)
        except ValueError as e:
            die(str(e))

        info({"major": "Major release detected.",
              "minor": "Minor release detected.",
              "alpha": "Alpha release detected.",
              "beta": "Beta release detected."}[kind])

    info(f"Repository root: {repo}")
    info(f"Core: {cfg.display_name} ({cfg.file_base})")

    # 2) Check that a .cor builder is available before doing anything expensive.
    core_file_tool = check_core_file_tool()

    # 3) Cross-check config.vhd or the configured replacement.
    check_config_vhd(repo, cfg, args.version)

    # 4) Alpha and beta releases: cross-check inofficial.md and git history.
    if kind in ("alpha", "beta"):
        commit = check_inofficial_md(repo, args.version, cfg.inofficial_md_policy)
        if commit is not None:
            check_git_commit(repo, commit, args.version)
    elif kind == "ignored":
        info("--ignore was passed; skipping alpha/beta release-row checks.")

    # 5) Resolve target boards.
    if args.targets is None:
        targets = cfg.boards
        info(f"No target list given - building all configured boards: "
             f"{', '.join(targets)}.")
        # Only when building everything do we warn about stale bitstreams,
        # so that targeted re-builds do not get spurious warnings about the
        # boards the user is intentionally not rebuilding.
        warn_if_stale(repo, targets)
    else:
        targets = parse_targets(args.targets, cfg)
        info(f"Building selected boards: {', '.join(targets)}.")

    # 6) Verify the requested bitstreams exist before we start copying.
    missing = [r for r in targets if not source_bit_path(repo, r).is_file()]
    if missing:
        die("Missing bitstream(s): " + ", ".join(
            str(source_bit_path(repo, r).relative_to(repo)) for r in missing
        ) + ". Run synthesis and implementation in Vivado for each board first.")

    # 7) Prepare the output folder. The second CLI argument is a parent
    #    folder; we create a release subfolder named <file_base>-<version>
    #    inside it and put all .bit / .cor files into that subfolder.
    parent = Path(args.output_folder).expanduser().resolve()
    out = parent / f"{cfg.file_base}-{args.version}"

    ctx = HookContext(
        repo=repo,
        out=out,
        version=args.version,
        kind=kind,
        targets=targets,
        config=cfg,
        force=args.force,
        ignore=args.ignore,
        verbatim=args.verbatim,
    )
    run_hook(hooks, "validate", ctx)

    parent.mkdir(parents=True, exist_ok=True)
    if out.exists() and any(out.iterdir()):
        if not args.force:
            die(f"Release folder already exists and is not empty: {out}\n"
                f"  Pick a different output folder, delete the existing one, "
                f"or pass -f / --force to overwrite.")
        warn(f"Release folder exists and is not empty; --force was given, "
             f"overwriting: {out}")
    out.mkdir(parents=True, exist_ok=True)

    if kind not in ("alpha", "beta"):
        stale_inofficial = out / INOFFICIAL_MD.name
        if stale_inofficial.is_file() or stale_inofficial.is_symlink():
            stale_inofficial.unlink()
        elif stale_inofficial.exists():
            die(f"Cannot remove stale non-file artifact: {stale_inofficial}")

    for stale_name in cfg.cleanup_stale_files:
        stale = out / stale_name
        if stale.is_file() or stale.is_symlink():
            stale.unlink()
        elif stale.exists():
            die(f"Cannot remove stale non-file artifact: {stale}")

    info(f"Parent folder:  {parent}")
    info(f"Release folder: {out}")

    # 8) Copy bitstreams (preserving mtime/atime) and generate .cor files.
    for rev in targets:
        src_bit = source_bit_path(repo, rev)
        dst_bit = out / dest_bit_name(cfg, args.version, rev)
        dst_cor = out / dest_cor_name(cfg, args.version, rev)

        info(f"[{rev}] Copying {src_bit.relative_to(repo)} -> "
             f"{dst_bit.name}")
        copy_preserving_timestamps(src_bit, dst_bit)
        ok(f"[{rev}] {dst_bit.name} ({dst_bit.stat().st_size:,} bytes)")

        info(f"[{rev}] Generating {dst_cor.name}")
        run_core_file_tool(cfg, core_file_tool, board_to_machine(rev), dst_bit,
                           args.version, dst_cor, args.force)
        if not dst_cor.is_file():
            die(f"[{rev}] {core_file_tool.name} did not produce {dst_cor}.")
        ok(f"[{rev}] {dst_cor.name} ({dst_cor.stat().st_size:,} bytes)")

    # 9) Generate the shell config file alongside the cores when configured.
    cfg_dst = None
    if cfg.shell_config_enabled:
        cfg_name = format_pattern(cfg.shell_config_filename, cfg, args.version)
        cfg_dst = out / cfg_name
        info(f"Generating config file {cfg_dst.name}")
        generate_shell_config(repo, cfg_dst)
        ok(f"{cfg_dst.name} ({cfg_dst.stat().st_size:,} bytes)")
    else:
        info("Shell config generation disabled by release.toml.")

    # 10) Ship release notes and alpha/beta notes according to policy.
    info("Copying VERSIONS.md into the release folder")
    vmd = copy_policy_file(repo, out, VERSIONS_MD, cfg.versions_md_policy)
    if vmd is not None:
        ok(f"{vmd.name} ({vmd.stat().st_size:,} bytes)")

    imd = None
    if kind in ("alpha", "beta"):
        info("Copying doc/inofficial.md into the release folder")
        imd = copy_policy_file(repo, out, INOFFICIAL_MD, cfg.inofficial_md_policy)
        if imd is not None:
            ok(f"{imd.name} ({imd.stat().st_size:,} bytes)")

    extra_artifacts = run_hook(hooks, "after_package", ctx)
    if extra_artifacts is None:
        extra_artifacts = []
    if not isinstance(extra_artifacts, (list, tuple)):
        die(f"{RELEASE_HOOKS}: after_package must return None, a list, or a tuple.")
    extra_artifacts = [Path(path) for path in extra_artifacts]

    # 11) Final summary so the default output stays concise and verbatim mode
    #     still ends with an at-a-glance view of what was produced.
    print_summary(args.version, kind, targets, cfg_dst, vmd, imd,
                  extra_artifacts, out)


def print_summary(version: str, kind: str, targets: tuple[str, ...],
                  cfg_dst, versions_md, inofficial_md,
                  extra_artifacts: list[Path], out: Path) -> None:
    bar = "=" * 64
    check = _c("32", "[OK]")
    warn_mark = _c("33", "[!!]")
    title = _c("1", f"Release Summary - {version} ({kind})")

    if _VERBATIM:
        print()
    print(_c("36", bar))
    print(" " + title)
    print(_c("36", bar))
    print(f" {check} Boards:        {', '.join(targets)} "
          f"(.bit + .cor for each)")
    if cfg_dst is not None:
        print(f" {check} Config file:   {cfg_dst.name} "
              f"({cfg_dst.stat().st_size:,} bytes)")
    if versions_md is not None:
        print(f" {check} VERSIONS.md:   {versions_md.stat().st_size:,} bytes "
              f"(timestamp preserved)")
    if inofficial_md is not None:
        print(f" {check} inofficial.md: {inofficial_md.stat().st_size:,} bytes "
              f"(timestamp preserved)")
    for artifact in extra_artifacts:
        if artifact.exists():
            print(f" {check} Extra:         {artifact.name} "
                  f"({artifact.stat().st_size:,} bytes)")
        else:
            print(f" {check} Extra:         {artifact}")
    print(f" {check} Release at:    {out}")
    if _WARNINGS:
        print()
        print(f" {warn_mark} {len(_WARNINGS)} warning(s) emitted during the run:")
        for w in _WARNINGS:
            # Keep summary lines short - show first line only of multi-line
            # warnings.
            first = w.splitlines()[0]
            if len(first) > 56:
                first = first[:53] + "..."
            print(f"      - {first}")
    print(_c("36", bar))


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        die("Interrupted.", code=130)
