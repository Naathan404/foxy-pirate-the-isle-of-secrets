import contextlib
import errno
import io
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

import godot_check


class GodotCheckTests(unittest.TestCase):
    def check_result(self, returncode, output):
        result = subprocess.CompletedProcess([], returncode, stdout=output)
        with patch("godot_check.subprocess.run", return_value=result):
            with contextlib.redirect_stdout(io.StringIO()):
                return godot_check.run_godot("godot", Path.cwd(), [], "test", 60)

    def test_success(self):
        self.assertTrue(self.check_result(0, "All checks passed\n"))

    def test_nonzero_exit_fails(self):
        self.assertFalse(self.check_result(1, ""))

    def test_script_error_with_zero_exit_fails(self):
        self.assertFalse(self.check_result(0, "SCRIPT ERROR: Parse Error\n"))

    def test_engine_error_with_zero_exit_fails(self):
        self.assertFalse(self.check_result(0, "ERROR: Failed loading resource\n"))

    def test_colored_error_fails(self):
        self.assertFalse(self.check_result(0, "\x1b[31mERROR:\x1b[0m bad resource\n"))

    def test_warning_is_not_an_error(self):
        self.assertTrue(self.check_result(0, "WARNING: informational\n"))

    def test_timeout_fails(self):
        error = subprocess.TimeoutExpired("godot", 60, output=b"partial log")
        with patch("godot_check.subprocess.run", side_effect=error):
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertFalse(
                    godot_check.run_godot("godot", Path.cwd(), [], "test", 60)
                )

    def test_linux_launcher_without_shebang_uses_bash(self):
        project = Path.cwd()
        result = subprocess.CompletedProcess([], 0, stdout="Imported successfully\n")
        with patch("godot_check.sys.platform", "linux"):
            with patch(
                "godot_check.subprocess.run",
                side_effect=[OSError(errno.ENOEXEC, "Exec format error"), result],
            ) as run:
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertTrue(
                        godot_check.run_godot(
                            "godot", project, ["--editor", "--import", "--quit"], "import", 300
                        )
                    )
        command = run.call_args_list[0].args[0]
        self.assertEqual(run.call_args_list[1].args[0], ["bash", *command])
        self.assertEqual(run.call_args_list[0].kwargs, run.call_args_list[1].kwargs)
        self.assertEqual(run.call_args_list[1].kwargs["timeout"], 300)

    def test_bash_launcher_still_rejects_godot_errors(self):
        result = subprocess.CompletedProcess([], 0, stdout="ERROR: Failed loading resource\n")
        with patch("godot_check.sys.platform", "linux"):
            with patch(
                "godot_check.subprocess.run",
                side_effect=[OSError(errno.ENOEXEC, "Exec format error"), result],
            ):
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertFalse(
                        godot_check.run_godot("godot", Path.cwd(), [], "test", 60)
                    )

    def test_missing_executable_does_not_retry_through_bash(self):
        with patch("godot_check.sys.platform", "linux"):
            with patch(
                "godot_check.subprocess.run",
                side_effect=FileNotFoundError(errno.ENOENT, "No such file"),
            ) as run:
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertFalse(
                        godot_check.run_godot("godot", Path.cwd(), [], "test", 60)
                    )
        self.assertEqual(run.call_count, 1)


if __name__ == "__main__":
    unittest.main()
