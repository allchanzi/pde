"""Reject local build paths and local ownership in release artifacts."""

import os
import sys
import tarfile
from pathlib import Path

roots = {
    Path.home(),
    Path(__file__).resolve().parents[2],
    *(Path(os.environ[name]) for name in ("CARGO_HOME", "RUSTUP_HOME") if os.environ.get(name)),
}
prefixes = [str(root).rstrip("/").encode() + b"/" for root in roots if root != Path("/")]


def check_content(name: str, data: bytes) -> None:
    for prefix in prefixes:
        if prefix in data:
            raise SystemExit(f"{name}: contains a local build path")


for argument in sys.argv[1:]:
    artifact = Path(argument)
    if artifact.name.endswith(".tar.gz"):
        with tarfile.open(artifact) as archive:
            for member in archive:
                if member.uid or member.gid or member.uname or member.gname:
                    raise SystemExit(f"{artifact}: contains local archive ownership")
                check_content(member.name, member.name.encode())
                check_content(member.name, member.linkname.encode())
                if member.isfile():
                    with archive.extractfile(member) as source:
                        check_content(member.name, source.read())
    else:
        check_content(str(artifact), artifact.read_bytes())
    print(f"Privacy check OK: {artifact.name}")
