#!/usr/bin/env python3
"""Build-time patch for WorkBuddy on Nix.

The official deb ships a patched Electron binary exposing the native API
electron.workbuddyStorage, which the app uses as the at-rest credential
bootstrap key source. The workbuddy-nix package replaces that binary with
stock nixpkgs Electron, so the API is missing and the app reports
"symmetricUnavailableCategory: invalid-key", which surfaces as
"CBC credential bootstrap channel closed early" errors in features such as
enhance prompt whenever a child session (e.g. headless codebuddy) enforces
the "fields" credential policy.

This script rewrites main/index.js so the key loader no longer touches
electron.workbuddyStorage. Instead it reads a persistent 32-byte secret from
~/.config/workbuddy-shim/at-rest-key.json (creating it on first run); the
app then derives the AES key as sha256(secret), exactly like the official
path does, so the key survives restarts and nothing else in the app changes.

Usage: python3 credential-bootstrap-patch.py <path-to-index.js>
"""
import pathlib
import sys

TARGET = "() => electron.workbuddyStorage.loggerGet()"
REPLACEMENT = (
    '() => (() => { '
    'const _fs=require("fs"), _os=require("os"), _path=require("path"), _crypto=require("crypto"); '
    'const _f=_path.join(_os.homedir(), ".config", "workbuddy-shim", "at-rest-key.json"); '
    'let _p=null; '
    'try { _p=JSON.parse(_fs.readFileSync(_f, "utf8")); } catch(_) {} '
    'if (!_p || _p.version!==1 || typeof _p.atRestSecretKey!=="string" || _p.atRestSecretKey.length===0) { '
    '_p={version:1, atRestSecretKey:_crypto.randomBytes(32).toString("base64")}; '
    'try { _fs.mkdirSync(_path.dirname(_f), {recursive:true}); _fs.writeFileSync(_f, JSON.stringify(_p), {mode:0o600}); } catch(_) {} '
    '} '
    'return JSON.stringify(_p); '
    '})()'
)

def main() -> int:
    if len(sys.argv) != 2:
        print("usage: credential-bootstrap-patch.py <index.js>", file=sys.stderr)
        return 2
    p = pathlib.Path(sys.argv[1])
    s = p.read_text(encoding="utf-8", errors="replace")
    n = s.count(TARGET)
    if n != 1:
        print(f"patch target found {n} times (expected 1); aborting", file=sys.stderr)
        return 1
    p.write_text(s.replace(TARGET, REPLACEMENT), encoding="utf-8")
    print(f"patched {p}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
