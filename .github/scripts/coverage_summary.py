"""Report line coverage, including files omitted by MoonBit's text summary."""

import argparse
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path


PACKAGES = {"core", "async", "exporters", "importers", "combinators", "tests"}
PROJECT_ROOT = Path(__file__).resolve().parents[2]


def package_name(filename):
    parts = filename.split("/")
    if parts[0] == "moon_zod" and len(parts) > 1:
        return parts[1]
    return parts[0]


def read_coverage(report):
    coverage = {}
    for source in ET.parse(report).getroot().findall(".//class"):
        name = source.attrib["filename"].replace("\\", "/")
        if Path(name).is_absolute():
            try:
                name = Path(name).relative_to(PROJECT_ROOT).as_posix()
            except ValueError:
                continue
        if package_name(name) not in PACKAGES:
            continue
        for line in source.findall("./lines/line"):
            lines = coverage.setdefault(name, {})
            number = int(line.attrib["number"])
            lines[number] = lines.get(number, False) or int(line.attrib["hits"]) > 0
    if not coverage:
        raise ValueError("No instrumented project lines found in coverage report")
    return coverage


def summarize(coverage, packages=PACKAGES):
    hits = [
        covered
        for name, lines in coverage.items()
        if package_name(name) in packages
        for covered in lines.values()
    ]
    return sum(hits), len(hits)


def ratio(counts):
    covered, total = counts
    percent = 100 * covered / total if total else 0
    return f"{covered}/{total} ({percent:.1f}%)"


def display(coverage):
    print("Per-file line coverage (covered / total):")
    for name, lines in sorted(coverage.items()):
        print(f"{name}: {ratio((sum(lines.values()), len(lines)))}")
    for package in ["core", "async"]:
        counts = summarize(coverage, {package})
        if counts[1]:
            print(f"::notice title={package} line coverage::{ratio(counts)}")
    print(f"::notice title=Line coverage::Selected packages: {ratio(summarize(coverage))}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", nargs="?", type=Path, help="Existing Cobertura XML report")
    report = parser.parse_args().report
    if report is not None:
        display(read_coverage(report))
    else:
        with tempfile.TemporaryDirectory(prefix="moon-zod-coverage-") as directory:
            report = Path(directory) / "coverage.xml"
            build = PROJECT_ROOT / "_build"
            traces = sorted(build.rglob("*.trace.source"))
            logs = sorted(build.glob("moonbit_coverage_*.txt"))
            if not traces or not logs:
                raise ValueError("Run workspace tests with --enable-coverage first")
            runtime_log = Path(directory) / "runtime.log"
            runtime_log.write_text(
                "\n".join(log.read_text(encoding="utf-8") for log in logs),
                encoding="utf-8",
            )
            subprocess.run(
                [
                    "moon", "coverage", "report", "-f", "cobertura", "-o", str(report),
                    "--absolute-file-paths", "--source-paths", str(PROJECT_ROOT),
                    "--runtime-log", str(runtime_log),
                    *(str(trace) for trace in traces),
                ],
                cwd=PROJECT_ROOT,
                check=True,
            )
            display(read_coverage(report))


if __name__ == "__main__":
    main()
