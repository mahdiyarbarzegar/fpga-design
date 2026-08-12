from pathlib import Path
from typing import Any
import yaml
import json
import sys


def find_project_root(marker: str = ".root") -> Path:
    current = Path.cwd()

    while True:
        if (current / marker).is_file():
            return current

        if current.parent == current:
            raise FileNotFoundError(
                f"Could not find '{marker}' in '{Path.cwd()}' or any parent directory"
            )

        current = current.parent


def load_yaml(path: str | Path) -> dict[str, Any]:
    path = Path(path)

    with path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f)

    if data is None:
        return {}

    if not isinstance(data, dict):
        raise TypeError(
            f"Expected a YAML mapping at the top level, got {type(data).__name__}"
        )

    return data


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <relative-yaml-path>", file=sys.stderr)
        return 1

    try:
        root = find_project_root()
        config = load_yaml(root / sys.argv[1])

        # Print as JSON for Tcl to consume.
        print(json.dumps(config))

        return 0

    except Exception as e:
        print(str(e), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
