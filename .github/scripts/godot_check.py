"""Run the same strict Godot checks locally and in GitHub Actions."""

import argparse
import errno
from pathlib import Path
import re
import subprocess
import sys


PROJECT_ROOT = Path(__file__).resolve().parents[2]
ANSI_ESCAPE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
GODOT_ERROR = re.compile(r"SCRIPT ERROR:|ERROR:")


def run_godot(engine, project, arguments, label, timeout):
    print(f"::group::{label}", flush=True)
    command = [engine, "--headless", "--path", str(project), *arguments]
    try:
        run_options = dict(
            cwd=project,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
            check=False,
        )
        try:
            result = subprocess.run(command, **run_options)
        except OSError as error:
            # setup-godot's Linux launcher can be a script without a shebang.
            # Bash accepts it; direct subprocess execution raises ENOEXEC.
            if error.errno != errno.ENOEXEC or not sys.platform.startswith("linux"):
                raise
            print("::notice::Retrying Godot launcher through Bash (ENOEXEC).", flush=True)
            result = subprocess.run(["bash", *command], **run_options)
        output = result.stdout or ""
        print(output, end="" if output.endswith("\n") else "\n", flush=True)
        passed = result.returncode == 0 and not GODOT_ERROR.search(
            ANSI_ESCAPE.sub("", output)
        )
        if not passed:
            print(f"::error::{label} failed (exit {result.returncode}); see log above.")
        return passed
    except subprocess.TimeoutExpired as error:
        output = error.stdout or ""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        print(output)
        print(f"::error::{label} timed out after {timeout}s.")
        return False
    except OSError as error:
        print(f"::error::{label}: {error}")
        return False
    finally:
        print("::endgroup::", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=("import", "tests", "smoke"))
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--project", type=Path, default=PROJECT_ROOT)
    options = parser.parse_args()
    project = options.project.resolve()
    if options.stage == "import":
        passed = run_godot(
            options.godot, project, ["--editor", "--import", "--quit"], "Import project", 300
        )
    elif options.stage == "smoke":
        settings = (project / "project.godot").read_text(encoding="utf-8-sig")
        if not re.search(r'^run/main_scene\s*=\s*"[^"\s]+"', settings, re.MULTILINE):
            print("::notice::Smoke test skipped: no main scene configured.")
            return 0
        passed = run_godot(
            options.godot, project, ["--quit-after", "10"], "Game startup", 60
        )
    else:
        test_files = sorted((project / "test").rglob("*_test.gd"))
        if not test_files:
            print("::notice::Tests skipped: no test/**/*_test.gd files found.")
            return 0
        failures = 0
        for test in test_files:
            relative = test.relative_to(project).as_posix()
            if not run_godot(options.godot, project, ["--script", relative], relative, 60):
                failures += 1
        print(f"Godot tests: {len(test_files) - failures}/{len(test_files)} passed.")
        passed = failures == 0
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
