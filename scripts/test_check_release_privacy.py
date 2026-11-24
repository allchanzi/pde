"""Local build paths must fail the release check, except inside upstream downloads."""
import io
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

CHECK = Path(__file__).with_name("check_release_privacy.py")


def passes(name: str) -> bool:
    with tempfile.TemporaryDirectory() as directory:
        archive = Path(directory) / "bundle.tar.gz"
        data = b"built in /home/example-builder/work/tool"
        with tarfile.open(archive, "w:gz") as tar:
            info = tarfile.TarInfo(name)
            info.size = len(data)
            tar.addfile(info, io.BytesIO(data))
        return subprocess.run([sys.executable, CHECK, archive], capture_output=True,
                              env={**os.environ, "HOME": "/home/example-builder"}).returncode == 0


for upstream in ("b/lib/nvim/bin/nvim", "b/bin/lazygit", "b/bin/lazydocker"):
    assert passes(upstream), upstream
for ours in ("b/bin/gtui", "b/pde/target/release/pde-tui", "b/pde/bin/lazygit"):
    assert not passes(ours), ours
print("Release privacy check passed")
