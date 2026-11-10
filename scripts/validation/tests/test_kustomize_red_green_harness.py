"""Offline regression harness for Kustomize failure propagation.

The harness is deliberately outside GitHub Actions.  It renders a known-good
fixture, proves a known-bad fixture exits non-zero, and checks the baseline
workflow's application-overlay accumulator is fail-closed.
"""

from pathlib import Path
import os
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[3]
HARNESS = ROOT / "scripts/validation/run-kustomize-red-green-harness.sh"
DOCUMENTATION = ROOT / "docs/testing/kustomize-red-green-harness.md"


class KustomizeRedGreenHarnessTests(unittest.TestCase):
    def run_harness(self, fixture: str) -> subprocess.CompletedProcess[str]:
        self.assertTrue(HARNESS.is_file(), f"missing harness: {HARNESS}")
        return subprocess.run(
            [str(HARNESS), "--fixture", fixture],
            cwd=ROOT,
            env=os.environ.copy(),
            capture_output=True,
            text=True,
            check=False,
        )

    def test_green_fixture_builds_successfully(self):
        result = self.run_harness("green")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("GREEN: Kustomize build succeeded", result.stdout)
        self.assertIn("GREEN: workflow accumulator is fail-closed", result.stdout)

    def test_red_fixture_fails_the_harness(self):
        result = self.run_harness("red")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("RED: Kustomize build failed as expected", result.stdout)

    def test_documentation_records_reproducible_baseline_and_matrix(self):
        content = DOCUMENTATION.read_text(encoding="utf-8")
        for required in (
            "814709b58b2ce406f0e4d3dcaef2eeaff2e4c7fd",
            "42410490999",
            "Kustomize Build & K8s Validation",
            "Blocking / non-blocking matrix",
            "Kustomize build failure",
            "0 rendered resources",
        ):
            with self.subTest(required=required):
                self.assertIn(required, content)


if __name__ == "__main__":
    unittest.main()
