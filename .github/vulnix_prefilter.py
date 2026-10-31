"""Deterministic pre-triage for vulnix findings.

Decides only clear cases from CVE 5 records and the derivations themselves:
the version is outside every affected range, the derivation applies a patch
that names the CVE, or the record is about a different product. Everything
else stays undecided.
"""

import argparse
import json
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

ECOSYSTEM_MARKERS = {
    "plugin",
    "gem",
    "extension",
    "module",
    "addon",
    "add-on",
    "theme",
    "jenkins",
    "wordpress",
    "drupal",
    "joomla",
    "npm",
    "pypi",
    "php",
    "ruby",
    "rubygems",
    "node",
    "nodejs",
    "python",
    "perl-module",
    "cpan",
    "android",
    "ios",
    "windows",
    "macos",
    "chrome",
    "firefox-extension",
}
SKIP_VERSION_TYPES = {"rpm", "git", "deb", "maven"}
UNBOUNDED = {"", "0", "*", "unspecified", "n/a", "-"}
PLACEHOLDER = {"", "n/a", "na", "unknown", "unspecified", "-"}
VERSION_RE = re.compile(r"^v?\d+(\.\d+)*([._+~-]?[a-z0-9]+)*$", re.I)
HASH_RE = re.compile(r"^[0-9a-f]{7,40}$", re.I)
STORE_PREFIX_RE = re.compile(r"^[a-z0-9]{32}-")


def is_version(text):
    text = str(text).strip()
    return bool(VERSION_RE.match(text)) and not HASH_RE.match(text)


def vkey(version):
    """Numeric sort key for a version string, None if it has no digits."""
    parts = re.findall(r"\d+|[a-z]+", str(version).lower())
    if not any(p.isdigit() for p in parts):
        return None
    key = []
    for p in parts:
        if p.isdigit():
            key.append((1, int(p)))
        elif p in {"alpha", "beta", "rc", "pre", "a", "b"}:
            key.append((-1, p))
        else:
            key.append((0, p))
    while key and key[-1] == (1, 0):
        key.pop()
    return key


def norm(text):
    return re.sub(r"[^a-z0-9]+", " ", str(text or "").lower()).split()


def load_cve(cve_id, cache_dir):
    path = cache_dir / f"{cve_id}.json"
    if not path.exists():
        url = f"https://cveawg.mitre.org/api/cve/{cve_id}"
        with urllib.request.urlopen(url, timeout=30) as resp:
            path.write_bytes(resp.read())
    return json.loads(path.read_text())


def matching_entries(record, pname):
    entries = record.get("containers", {}).get("cna", {}).get("affected", []) or []
    tokens = set(norm(pname))
    matched, foreign, ambiguous = [], [], []
    for entry in entries:
        raw_product = (
            str(entry.get("product") or entry.get("packageName") or "").strip().lower()
        )
        if raw_product in PLACEHOLDER:
            continue
        product = norm(entry.get("product")) + norm(entry.get("packageName"))
        vendor = (
            []
            if str(entry.get("vendor") or "").strip().lower() in PLACEHOLDER
            else norm(entry.get("vendor"))
        )
        if tokens and tokens <= set(product):
            extra = (set(product) | set(vendor)) - tokens
            if extra & ECOSYSTEM_MARKERS:
                foreign.append(entry)
            else:
                matched.append(entry)
        elif tokens & (set(product) | set(vendor)):
            ambiguous.append(entry)
        else:
            foreign.append(entry)
    return matched, foreign, ambiguous


def fixed_in_version(entries, version):
    our = vkey(version)
    if our is None:
        return None
    reasons = []
    for entry in entries:
        if entry.get("defaultStatus") == "affected" and not entry.get("versions"):
            return None
        ranges = [
            v for v in entry.get("versions", []) or [] if v.get("status") == "affected"
        ]
        if not ranges:
            return None
        for rng in ranges:
            if rng.get("versionType") in SKIP_VERSION_TYPES:
                return None
            low = str(rng.get("version", "")).strip()
            lt, le = rng.get("lessThan"), rng.get("lessThanOrEqual")
            if lt in UNBOUNDED or le in UNBOUNDED:
                return None
            if low.lower() not in UNBOUNDED and not is_version(low):
                return None
            if any(b is not None and not is_version(b) for b in (lt, le)):
                return None
            if lt is None and le is None:
                exact = vkey(low)
                if exact is None or exact == our:
                    return None
                reasons.append(f"only {low} affected")
                continue
            upper = vkey(lt if lt is not None else le)
            if upper is None:
                return None
            above = our >= upper if lt is not None else our > upper
            lower = None if low.lower() in UNBOUNDED else vkey(low)
            below = lower is not None and our < lower
            if not (above or below):
                return None
            bound = f"< {lt}" if lt is not None else f"<= {le}"
            reasons.append(f"affected {low or '*'} {bound}")
    if not reasons:
        return None
    return "; ".join(sorted(set(reasons)))


def derivation_patches(drv, cache):
    """Store paths of the patches a derivation actually applies."""
    if drv in cache:
        return cache[drv]
    patches = []
    if drv:
        proc = subprocess.run(
            ["nix", "derivation", "show", drv], capture_output=True, text=True
        )
        if proc.returncode == 0:
            data = json.loads(proc.stdout)
            for value in (data.get("derivations") or data).values():
                env = value.get("env", {})
                sources = [
                    env.get("patches"),
                    (value.get("structuredAttrs") or {}).get("patches"),
                ]
                if "__json" in env:
                    sources.append(json.loads(env["__json"]).get("patches"))
                for raw in sources:
                    if isinstance(raw, str):
                        raw = raw.split()
                    patches.extend(str(x) for x in raw or [])
    cache[drv] = patches
    return patches


def patched_in_derivation(cve_id, drv, cache):
    needle = cve_id.encode()
    for patch in derivation_patches(drv, cache):
        path = Path(patch)
        name = STORE_PREFIX_RE.sub("", path.name)
        if cve_id.lower() in name.lower():
            return name
        if not path.exists() and patch.startswith("/nix/store/"):
            subprocess.run(
                ["nix-store", "--realise", patch], capture_output=True, text=True
            )
        if path.is_file():
            try:
                if needle in path.read_bytes():
                    return name
            except OSError:
                continue
    return None


def triage(findings, cache_dir):
    drv_cache = {}
    out = []
    for pkg in findings:
        pname, version, name = pkg["pname"], pkg["version"], pkg["name"]
        for cve_id in pkg["affected_by"]:
            decision = {
                "cve": cve_id,
                "package": name,
                "verdict": "undecided",
                "reason": "",
            }
            try:
                record = load_cve(cve_id, cache_dir)
            except Exception as exc:
                decision["reason"] = f"CVE record unavailable: {exc}"
                out.append(decision)
                continue
            matched, foreign, ambiguous = matching_entries(record, pname)
            patch = patched_in_derivation(cve_id, pkg.get("derivation", ""), drv_cache)
            if patch:
                decision.update(
                    verdict="patched", reason=f"{cve_id} in applied patch {patch}"
                )
            elif not matched and not ambiguous and foreign:
                products = sorted(
                    {
                        f"{e.get('vendor', '?')}/{e.get('product', e.get('packageName', '?'))}"
                        for e in foreign
                    }
                )
                decision.update(
                    verdict="false_positive",
                    reason="affects " + ", ".join(products[:3]),
                )
            elif matched:
                why = fixed_in_version(matched, version)
                if why:
                    decision.update(
                        verdict="fixed_in_version",
                        reason=f"{version} outside the affected range ({why})",
                    )
            out.append(decision)
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("vulnix_json", type=Path)
    parser.add_argument("--cve-cache", type=Path, required=True)
    args = parser.parse_args()
    args.cve_cache.mkdir(parents=True, exist_ok=True)
    findings = json.loads(args.vulnix_json.read_text())
    json.dump(
        triage(findings, args.cve_cache), sys.stdout, ensure_ascii=False, indent=1
    )


if __name__ == "__main__":
    main()
