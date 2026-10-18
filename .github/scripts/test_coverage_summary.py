import tempfile
import unittest
from pathlib import Path

from coverage_summary import read_coverage, summarize


class CoverageSummaryTests(unittest.TestCase):
    def read(self, classes):
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "coverage.xml"
            report.write_text(
                '<coverage><packages><package><classes>'
                + classes
                + '</classes></package></packages></coverage>',
                encoding="utf-8",
            )
            return read_coverage(report)

    def test_fully_covered_files_contribute_to_totals(self):
        coverage = self.read('''
          <class filename="async/schema.mbt"><lines>
            <line number="1" hits="4"/><line number="2" hits="1"/>
          </lines></class>
          <class filename="async/sse.mbt"><lines>
            <line number="1" hits="1"/><line number="2" hits="0"/>
          </lines></class>
          <class filename="core/string.mbt"><lines>
            <line number="1" hits="3"/>
          </lines></class>
          <class filename=".mooncakes/vendor/dep.mbt"><lines>
            <line number="1" hits="0"/>
          </lines></class>
        ''')
        self.assertEqual(summarize(coverage, {"async"}), (3, 4))
        self.assertEqual(summarize(coverage), (4, 5))

    def test_windows_paths_and_duplicate_backend_lines_are_merged(self):
        coverage = self.read(r'''
          <class filename="async\schema.mbt"><lines>
            <line number="1" hits="0"/><line number="2" hits="1"/>
          </lines></class>
          <class filename="async/schema.mbt"><lines>
            <line number="1" hits="1"/><line number="2" hits="0"/>
          </lines></class>
        ''')
        self.assertEqual(list(coverage), ["async/schema.mbt"])
        self.assertEqual(summarize(coverage), (2, 2))

    def test_empty_or_unrelated_reports_fail_instead_of_reporting_success(self):
        for classes in ["", '<class filename="vendor/dep.mbt"><lines/></class>']:
            with self.subTest(classes=classes), self.assertRaises(ValueError):
                self.read(classes)


if __name__ == "__main__":
    unittest.main()
