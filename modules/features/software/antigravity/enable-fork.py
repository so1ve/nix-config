import io
import mmap
import struct
import sys
import zipfile


def find_web_bundle(server):
    # The language server embeds multiple ZIPs. Find the one with the web UI.
    end = len(server)
    while (end := server.rfind(b"PK\x05\x06", 0, end)) != -1:
        if end + 22 > len(server):
            continue
        directory_size, directory_offset, comment_size = struct.unpack_from(
            "<IIH", server, end + 12
        )
        start = end - directory_size - directory_offset
        stop = end + 22 + comment_size
        if not 0 <= start < stop <= len(server):
            continue
        if server[start : start + 4] != b"PK\x03\x04":
            continue
        bundle = zipfile.ZipFile(io.BytesIO(server[start:stop]))
        if {"index.html", "main.js"}.issubset(bundle.namelist()):
            return bundle
        bundle.close()
    raise ValueError("Could not find the embedded Antigravity web UI")


with open(sys.argv[1], "rb") as binary, mmap.mmap(
    binary.fileno(), 0, access=mmap.ACCESS_READ
) as server, find_web_bundle(server) as original:
    disabled = b"conversationForkingEnabled:!1,"
    script = original.read("main.js")
    if script.count(disabled) != 1:
        raise ValueError("Expected one disabled Antigravity conversation fork setting")
    script = script.replace(disabled, b"conversationForkingEnabled:!0,")

    with zipfile.ZipFile(sys.argv[2], "w") as patched:
        for entry in original.infolist():
            contents = script if entry.filename == "main.js" else original.read(entry)
            patched.writestr(entry, contents)
