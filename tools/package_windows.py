"""Package an already exported 0.03 build and verify every compressed entry."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from hashlib import sha256

root = Path(__file__).resolve().parents[1]
folder = root / 'build/RAVAGE-0.03-Windows'
archive = folder.with_suffix('.zip')
assert (folder / 'RAVAGE.exe').is_file(), 'Run build_windows.ps1 first'
with ZipFile(archive, 'w', ZIP_DEFLATED, compresslevel=9) as z:
    for path in sorted(folder.rglob('*')):
        if path.is_file():
            z.write(path, path.relative_to(folder.parent))
with ZipFile(archive) as z:
    assert z.testzip() is None, 'ZIP CRC failure'
    packed = sha256(z.read(folder.name + '/RAVAGE.exe')).hexdigest()
assert packed == sha256((folder / 'RAVAGE.exe').read_bytes()).hexdigest()
digest = sha256(archive.read_bytes()).hexdigest()
archive.with_suffix('.zip.sha256').write_text(f'{digest}  {archive.name}\n', encoding='ascii')
print(f'ZIP verified: {archive.stat().st_size} bytes; SHA256 {digest}')
