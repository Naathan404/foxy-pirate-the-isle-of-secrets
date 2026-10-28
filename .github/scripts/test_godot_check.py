import contextlib
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


if __name__ == "__main__":
    unittest.main()
