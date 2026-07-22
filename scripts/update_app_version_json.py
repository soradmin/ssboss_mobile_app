import json
import os
import re
from pathlib import Path


def parse_flutter_version(pubspec_text: str) -> tuple[str, int]:
    """
    Expects Flutter version format: `version: X.Y.Z+BUILD`
    """
    m = re.search(r"(?m)^version:\s*([0-9A-Za-z\.\-]+)\+([0-9]+)\s*$", pubspec_text)
    if not m:
        raise ValueError("Cannot find Flutter version in pubspec.yaml (expected: version: 1.2.3+45)")
    return m.group(1), int(m.group(2))


def str_to_bool(v: str) -> bool:
    return v.strip().lower() in {"1", "true", "yes", "y", "on"}


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    pubspec_path = repo_root / "pubspec.yaml"
    app_version_path = repo_root / "server_code" / "public" / "app-version.json"

    pubspec_text = pubspec_path.read_text(encoding="utf-8")
    latest_version, latest_build = parse_flutter_version(pubspec_text)

    data: dict = {}
    if app_version_path.exists():
        data = json.loads(app_version_path.read_text(encoding="utf-8"))

    min_version = os.getenv("MIN_VERSION", latest_version)
    min_build = int(os.getenv("MIN_BUILD", str(latest_build)))

    # Default: not forced update on every release build.
    force_update_env = os.getenv("FORCE_UPDATE")
    if force_update_env is None:
        force_update = False
    else:
        force_update = str_to_bool(force_update_env)

    # Keep store URLs/message if already present, but refresh version fields.
    data.update(
        {
            "latest_version": latest_version,
            "latest_build": latest_build,
            "min_version": min_version,
            "min_build": min_build,
            "force_update": force_update,
        }
    )

    app_version_path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"Updated {app_version_path} -> latest_version={latest_version}+{latest_build}")


if __name__ == "__main__":
    main()

