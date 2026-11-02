"""Check that each workspace release archive is complete and self-contained."""

import re
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def main():
    for directory in ("core", "exporters", "importers", "moon_zod"):
        manifest = (ROOT / directory / "moon.mod").read_text(encoding="utf-8")
        fields = dict(re.findall(r'^(name|version|readme) = "([^"]+)"', manifest, re.M))
        filename = fields["name"].replace("/", "-") + "-" + fields["version"] + ".zip"
        archive = ROOT / "_build" / "publish" / filename
        with zipfile.ZipFile(archive) as package:
            files = set(package.namelist())
            required = {"moon.mod", "moon.pkg", "LICENSE", fields["readme"]}
            missing = required - files
            if missing:
                raise ValueError(f"{filename}: missing {sorted(missing)}")
            if package.read("moon.mod").decode("utf-8").replace("\r\n", "\n") != manifest:
                raise ValueError(f"{filename}: archive manifest differs from source")
            if any(Path(name).name == "moon.work" or name.endswith("/moon.mod") for name in files):
                raise ValueError(f"{filename}: contains workspace or nested module manifests")
            print(f"{filename}: verified {len(files)} files")


if __name__ == "__main__":
    main()
