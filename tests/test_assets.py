from pathlib import Path

import evafs.io.assets as assets


def test_guess_type():
    assert assets.guess_type(Path("file.json")) == "application/json"
