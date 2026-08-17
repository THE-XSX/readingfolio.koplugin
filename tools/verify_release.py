import os
import re
import sys
import glob

def test_syntax_and_structure():
    print("=== 1. Checking Lua files and require/bit bans ===")
    errors = []
    bit_pattern = re.compile(r'(?:require\s*\(?[\'\"]bit[\'\"]|[^a-zA-Z0-9_\.]bit\.[a-zA-Z0-9_]+\s*\()')
    lua_files = glob.glob("**/*.lua", recursive=True)
    
    for f in lua_files:
        if f.startswith("tests"):
            continue
        with open(f, "r", encoding="utf-8") as handle:
            lines = handle.readlines()
        for i, line in enumerate(lines, 1):
            clean_line = line.split("--")[0]
            if bit_pattern.search(clean_line):
                errors.append(f"{f}:{i} uses LuaJIT-only `bit` library: {line.strip()}")
                
    if errors:
        for e in errors:
            print("ERROR:", e)
    else:
        print(f"Passed: All {len(lua_files)} Lua files are free of `bit` library.")

def test_i18n_parity():
    print("\n=== 2. Checking i18n 1:1 key parity ===")
    def extract_keys(path):
        with open(path, "r", encoding="utf-8") as handle:
            content = handle.read()
        return re.findall(r'\[\"([^\"]+)\"\]\s*=', content)

    zh_keys = extract_keys("i18n/locales/zh_CN.lua")
    en_keys = extract_keys("i18n/locales/en.lua")

    zh_set = set(zh_keys)
    en_set = set(en_keys)

    print(f"zh_CN keys: {len(zh_keys)} (unique: {len(zh_set)})")
    print(f"en keys:    {len(en_keys)} (unique: {len(en_set)})")

    diff1 = zh_set - en_set
    diff2 = en_set - zh_set

    if diff1:
        print("ERROR: Keys in zh_CN but not in en:", diff1)
    if diff2:
        print("ERROR: Keys in en but not in zh_CN:", diff2)

    import collections
    def find_dups(path):
        keys = []
        with open(path, "r", encoding="utf-8") as f:
            for idx, line in enumerate(f, 1):
                m = re.search(r'\["([^"]+)"\]\s*=', line)
                if m:
                    keys.append((m.group(1), idx))
        counts = collections.defaultdict(list)
        for k, idx in keys:
            counts[k].append(idx)
        return {k: v for k, v in counts.items() if len(v) > 1}

    zh_dups = find_dups("i18n/locales/zh_CN.lua")
    en_dups = find_dups("i18n/locales/en.lua")
    if zh_dups:
        print("WARNING: Duplicate keys in zh_CN.lua:", zh_dups)
    if en_dups:
        print("WARNING: Duplicate keys in en.lua:", en_dups)

def test_style_registry():
    print("\n=== 3. Checking Style Registry vs Style files ===")
    with open("styles/style_registry.lua", "r", encoding="utf-8") as f:
        content = f.read()
    m = re.search(r'STYLE_FILES\s*=\s*\{([^}]+)\}', content)
    if not m:
        print("ERROR: STYLE_FILES not found in styles/style_registry.lua")
        return
    registered = [x.strip(' \t\n\r"\'') for x in m.group(1).split(",") if x.strip(' \t\n\r"\'')]
    print("Registered styles in registry:", registered)

    style_files = [os.path.splitext(os.path.basename(p))[0] for p in glob.glob("styles/*.lua") 
                   if os.path.basename(p) not in ("style_interface.lua", "style_registry.lua")]
    print("Actual style files:", sorted(style_files))

    missing = set(style_files) - set(registered)
    extra = set(registered) - set(style_files)
    if missing:
        print("ERROR: Styles missing from registry:", missing)
    if extra:
        print("ERROR: Styles in registry but no file:", extra)
    if not missing and not extra:
        print(f"Passed: All {len(registered)} styles correctly registered.")

def test_package_and_versions():
    print("\n=== 4. Checking Package Script & Version Consistency ===")
    with open("_meta.lua", "r", encoding="utf-8") as f:
        meta_ver = re.search(r'version\s*=\s*"([^"]+)"', f.read())
    meta_v = meta_ver.group(1) if meta_ver else None

    readme_v = None
    unreleased_present = False
    with open("README.md", "r", encoding="utf-8") as f:
        for line in f:
            if line.startswith("###") and ("未发布" in line or "Unreleased" in line):
                unreleased_present = True
            if line.startswith("###") and not readme_v:
                m = re.search(r"v(\d+\.\d+\.\d+)", line)
                if m:
                    readme_v = m.group(1)

    print(f"_meta.lua version: {meta_v}")
    print(f"README.md changelog top version: {readme_v}")
    print(f"README.md has Unreleased block: {unreleased_present}")

    if unreleased_present:
        print("WARNING / RELEASE BLOCKER: README.md still contains '### 未发布 / Unreleased' block. For a formal release, this should be converted to a specific release version (e.g., v1.6.1 or v1.6.0).")

    if meta_v != readme_v:
        print(f"WARNING / RELEASE BLOCKER: Version mismatch: _meta.lua ({meta_v}) != README.md ({readme_v})")
    else:
        print(f"Version check: _meta.lua and top README.md version match ({meta_v})")

if __name__ == "__main__":
    test_syntax_and_structure()
    test_i18n_parity()
    test_style_registry()
    test_package_and_versions()
