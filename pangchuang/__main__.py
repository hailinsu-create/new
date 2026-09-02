"""旁窗 entrypoint."""

from __future__ import annotations

from pangchuang.ui import run_app


def main() -> None:
    raise SystemExit(run_app())


if __name__ == "__main__":
    main()
