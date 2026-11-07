#!/usr/bin/env python3
"""Convert Adblock-Plus-syntax filter lists to WebKit content-blocker JSON.

Usage: python3 Scripts/build_blocklists.py [--fetch] [--src DIR]

  --fetch   download the upstream lists first (EasyList, EasyPrivacy, Easylist Cookie List)
  --src DIR directory holding easylist.txt / easyprivacy.txt / fanboy-cookiemonster.txt
            (default: ./.blocklist-src, gitignored)

Output: Packages/Waffle/Sources/WaffleFeatureGrid/Resources/ContentBlocking/
        ads.json.zlib, privacy.json.zlib, cookies.json.zlib, manifest.json

Only the filter subset WebKit can express is converted; everything else is skipped
(counts are printed). See Packages/Waffle/Sources/WaffleFeatureGrid/Resources/ContentBlocking/README.md
for licensing and the update procedure.
"""
import json, os, re, sys, urllib.request, zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Packages/Waffle/Sources/WaffleFeatureGrid/Resources/ContentBlocking")
SOURCES = {
    "ads": ("easylist.txt", "https://easylist.to/easylist/easylist.txt", "EasyList"),
    "privacy": ("easyprivacy.txt", "https://easylist.to/easylist/easyprivacy.txt", "EasyPrivacy"),
    "cookies": ("fanboy-cookiemonster.txt", "https://secure.fanboy.co.nz/fanboy-cookiemonster.txt", "Easylist Cookie List"),
}
TYPES = {"script": "script", "image": "image", "stylesheet": "style-sheet", "object": "media",
         "xmlhttprequest": "fetch", "subdocument": "document", "font": "font", "media": "media",
         "ping": "ping", "popup": "popup", "other": "raw"}
ALL_TYPES = ["document", "image", "style-sheet", "script", "font", "raw", "svg-document", "media", "popup", "ping", "fetch"]
# Only the resource types an ad list sensibly targets; "document" (main frame) is excluded
# unless the filter says $document so a user's navigation is never blocked.
DEFAULT_TYPES = [t for t in ALL_TYPES if t not in ("document",)]
SAFE_SELECTOR = re.compile(r'^[A-Za-z0-9_\-\.\#\[\]="\'\*\^\$~\|\s>\+,:()%]+$')
BAD_PSEUDO = re.compile(r':(?!not\(|first-child|last-child|nth-child)[a-z\-]+', re.I)

def regex_for(pattern):
    """ABP URL pattern -> WebKit-safe regex (no alternation/lookahead)."""
    anchor_domain = pattern.startswith("||")
    anchor_start = (not anchor_domain) and pattern.startswith("|")
    if anchor_domain: pattern = pattern[2:]
    elif anchor_start: pattern = pattern[1:]
    anchor_end = pattern.endswith("|") and not pattern.endswith("||")
    if anchor_end: pattern = pattern[:-1]
    if pattern.startswith("/") and pattern.endswith("/") and len(pattern) > 2:
        return None  # raw regex filters use unsupported syntax
    out = []
    for i, ch in enumerate(pattern):
        if ch == "*": out.append(".*")
        elif ch == "^":
            out.append("[/:?#&=;]" if i != len(pattern) - 1 else "[/:?#&=;]?")
        elif ch in ".+?()[]{}|\\$": out.append("\\" + ch)
        else: out.append(ch)
    body = "".join(out)
    if anchor_domain: body = r"^[a-z][a-z0-9+.\-]*://([^/?#]*\.)?" + body
    elif anchor_start: body = "^" + body
    if anchor_end: body += "$"
    return body

def parse_domains(s, prefix_star=False):
    pos, neg = [], []
    for d in re.split(r"[|,]", s):
        d = d.strip().lower()
        if not d: continue
        neg_d = d.startswith("~")
        d = d.lstrip("~")
        if not re.fullmatch(r"[a-z0-9.\-]+", d): return None
        (neg if neg_d else pos).append(("*" + d) if True else d)
    return pos, neg

def convert(lines):
    block, css, exc = [], [], []
    generic_sel = []
    stats = {"net": 0, "exc": 0, "css": 0, "skipped": 0}
    seen = set()
    for raw in lines:
        line = raw.strip()
        if not line or line.startswith("!") or line.startswith("["): continue
        if not line.isascii(): stats["skipped"] += 1; continue
        # cosmetic
        m = re.match(r"^([^#$]*)(#@?#)(.+)$", line)
        if m and "#?#" not in line and "#$#" not in line and "#%#" not in line:
            doms, kind, sel = m.groups()
            if kind == "#@#": stats["skipped"] += 1; continue
            if not SAFE_SELECTOR.match(sel) or BAD_PSEUDO.search(sel) or "{" in sel or "+js" in sel:
                stats["skipped"] += 1; continue
            if doms:
                pd = parse_domains(doms)
                if not pd or (pd[0] and pd[1]): stats["skipped"] += 1; continue
                trig = {"url-filter": ".*"}
                if pd[0]: trig["if-domain"] = pd[0]
                else: trig["unless-domain"] = pd[1]
                key = ("d", sel, tuple(pd[0]), tuple(pd[1]))
                if key in seen: continue
                seen.add(key)
                css.append({"trigger": trig, "action": {"type": "css-display-none", "selector": sel}})
            else:
                if ("g", sel) in seen: continue
                seen.add(("g", sel)); generic_sel.append(sel)
            stats["css"] += 1
            continue
        if "##" in line or "#?#" in line or "#$#" in line or "#@#" in line or "#%#" in line:
            stats["skipped"] += 1; continue
        # network
        is_exc = line.startswith("@@")
        if is_exc: line = line[2:]
        opts = ""
        if "$" in line:
            idx = line.rfind("$")
            pat, opts = line[:idx], line[idx + 1:]
        else: pat = line
        if not pat: stats["skipped"] += 1; continue
        types, neg_types, load, dom, ok = [], [], None, None, True
        for o in [x for x in opts.split(",") if x]:
            neg = o.startswith("~"); name = o.lstrip("~")
            if name in ("third-party", "3p"): load = "first-party" if neg else "third-party"
            elif name in ("first-party", "1p"): load = "third-party" if neg else "first-party"
            elif name in TYPES:
                (neg_types if neg else types).append(TYPES[name])
            elif name.startswith("domain="):
                dom = parse_domains(name[7:])
                if dom is None or (dom[0] and dom[1]): ok = False
            elif name in ("important", "match-case") : pass
            else: ok = False
        if not ok: stats["skipped"] += 1; continue
        rx = regex_for(pat)
        if rx is None or not rx or rx in (".*", "^"): stats["skipped"] += 1; continue
        trig = {"url-filter": rx}
        if types: trig["resource-type"] = sorted(set(types))
        elif neg_types: trig["resource-type"] = [t for t in DEFAULT_TYPES if t not in neg_types]
        elif not any(o.lstrip("~") in ("document",) for o in opts.split(",")):
            trig["resource-type"] = DEFAULT_TYPES
        if load: trig["load-type"] = [load]
        if dom:
            if dom[0]: trig["if-domain"] = dom[0]
            elif dom[1]: trig["unless-domain"] = dom[1]
        rule = {"trigger": trig, "action": {"type": "ignore-previous-rules" if is_exc else "block"}}
        key = json.dumps(rule, sort_keys=True)
        if key in seen: continue
        seen.add(key)
        (exc if is_exc else block).append(rule)
        stats["exc" if is_exc else "net"] += 1
    # Batch generic selectors; one rule per chunk keeps the rule count low.
    generic_rules = []
    for i in range(0, len(generic_sel), 80):
        generic_rules.append({"trigger": {"url-filter": ".*"},
                              "action": {"type": "css-display-none", "selector": ", ".join(generic_sel[i:i + 80])}})
    return block + generic_rules + css + exc, stats

def header(text, key):
    v = re.search(r"^! (?:Version|Last modified):\s*(.+)$", text, re.M)
    return v.group(1).strip() if v else "unknown"

def main():
    args = sys.argv[1:]
    src = os.path.join(ROOT, ".blocklist-src")
    if "--src" in args: src = args[args.index("--src") + 1]
    if "--fetch" in args:
        os.makedirs(src, exist_ok=True)
        for fname, url, _ in SOURCES.values():
            urllib.request.urlretrieve(url, os.path.join(src, fname))
    os.makedirs(OUT, exist_ok=True)
    manifest = {"lists": []}
    for ident, (fname, url, title) in SOURCES.items():
        text = open(os.path.join(src, fname), encoding="utf-8", errors="ignore").read()
        rules, stats = convert(text.splitlines())
        if len(rules) > 140000: sys.exit(f"{ident}: {len(rules)} rules exceeds WebKit's 150k limit")
        # Raw DEFLATE (what Foundation's NSData `.zlib` algorithm decodes); keeps install size small.
        comp = zlib.compressobj(9, zlib.DEFLATED, -15)
        blob = json.dumps(rules, separators=(",", ":")).encode()
        with open(os.path.join(OUT, ident + ".json.zlib"), "wb") as f:
            f.write(comp.compress(blob) + comp.flush())
        print(ident, len(rules), stats)
        manifest["lists"].append({"id": ident, "title": title, "source": url, "version": header(text, ident), "rules": len(rules)})
    with open(os.path.join(OUT, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")

if __name__ == "__main__": main()
