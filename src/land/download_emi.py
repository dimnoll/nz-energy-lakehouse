"""Download v1 EMI CSVs onto this machine. Do not run this from Databricks compute."""

from __future__ import annotations

import argparse
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from datetime import date, timedelta
from pathlib import Path

ACCOUNT = "https://emidatasets.blob.core.windows.net/publicdata"
# Public container SAS published by the Electricity Authority (not a personal secret).
SAS = "sv=2021-10-04&si=publicdata&sr=c&sig=f034UWz1xmMbk89jd76zY0M%2BwycFDhhumejUrjqlfIw%3D"
PRICES_PREFIX = "Datasets/Wholesale/DispatchAndPricing/FinalEnergyPrices/"
NSP_PREFIX = "Datasets/Wholesale/MappingsAndGeospatial/NetworkSupplyPointsTable/"
PRICE_NAME = re.compile(
    r"^(?P<ymd>\d{8})_FinalEnergyPrices(?P<interim>_I)?\.csv$"
)
NSP_NAME = re.compile(r"^(?P<ymd>\d{8})_NetworkSupplyPointsTable\.csv$")
REPO_ROOT = Path(__file__).resolve().parents[2]
LANDING = REPO_ROOT / "data" / "landing"


@dataclass(frozen=True)
class Blob:
    name: str
    size: int

    @property
    def filename(self) -> str:
        return self.name.rsplit("/", 1)[-1]


def blob_url(name: str) -> str:
    quoted = urllib.parse.quote(name, safe="/")
    return f"{ACCOUNT}/{quoted}?{SAS}"


def list_blobs(prefix: str) -> list[Blob]:
    blobs: list[Blob] = []
    marker = ""
    while True:
        query = {
            "restype": "container",
            "comp": "list",
            "prefix": prefix,
            "maxresults": "5000",
        }
        if marker:
            query["marker"] = marker
        url = f"{ACCOUNT}?{urllib.parse.urlencode(query)}&{SAS}"
        with urllib.request.urlopen(url, timeout=60) as resp:
            root = ET.fromstring(resp.read())
        for node in root.findall("Blobs/Blob"):
            name = node.findtext("Name") or ""
            if name.endswith("/"):
                continue
            size = int(node.findtext("Properties/Content-Length") or "0")
            if size <= 0:
                continue
            blobs.append(Blob(name=name, size=size))
        marker = root.findtext("NextMarker") or ""
        if not marker:
            break
    return blobs


def pick_price_days(blobs: list[Blob], days: int) -> list[Blob]:
    best: dict[str, Blob] = {}
    for blob in blobs:
        match = PRICE_NAME.match(blob.filename)
        if not match:
            continue
        ymd = match.group("ymd")
        interim = bool(match.group("interim"))
        current = best.get(ymd)
        if current is None:
            best[ymd] = blob
            continue
        current_interim = current.filename.endswith("_I.csv")
        if current_interim and not interim:
            best[ymd] = blob
    chosen = [best[ymd] for ymd in sorted(best, reverse=True)[:days]]
    chosen.reverse()
    return chosen


def pick_latest_nsp(blobs: list[Blob]) -> Blob:
    dated = []
    for blob in blobs:
        match = NSP_NAME.match(blob.filename)
        if match:
            dated.append((match.group("ymd"), blob))
    if not dated:
        raise SystemExit("No NetworkSupplyPointsTable CSV found in the EMI container.")
    dated.sort()
    return dated[-1][1]


def download(blob: Blob, dest_dir: Path) -> Path:
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / blob.filename
    if dest.exists() and dest.stat().st_size == blob.size:
        print(f"skip  {blob.filename} ({blob.size} bytes)")
        return dest
    req = urllib.request.Request(blob_url(blob.name), method="GET")
    with urllib.request.urlopen(req, timeout=120) as resp, dest.open("wb") as out:
        out.write(resp.read())
    print(f"got   {blob.filename} ({dest.stat().st_size} bytes)")
    return dest


def month_prefixes(days: int, extra: int = 14) -> list[str]:
    end = date.today()
    start = end - timedelta(days=days + extra)
    months: list[str] = []
    cursor = date(start.year, start.month, 1)
    while cursor <= end:
        months.append(f"{cursor.year:04d}{cursor.month:02d}")
        if cursor.month == 12:
            cursor = date(cursor.year + 1, 1, 1)
        else:
            cursor = date(cursor.year, cursor.month + 1, 1)
    return months


def peek_header(path: Path) -> str:
    with path.open("r", encoding="utf-8-sig", newline="") as fh:
        return fh.readline().strip()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--days", type=int, default=90)
    args = parser.parse_args()

    price_blobs: list[Blob] = []
    for month in month_prefixes(args.days):
        price_blobs.extend(list_blobs(f"{PRICES_PREFIX}{month}"))
    prices = pick_price_days(price_blobs, args.days)
    if not prices:
        raise SystemExit("No FinalEnergyPrices daily files found for the requested window.")

    nsp = pick_latest_nsp(list_blobs(NSP_PREFIX))

    price_dir = LANDING / "final-energy-prices"
    nsp_dir = LANDING / "network-supply-points"
    for blob in prices:
        download(blob, price_dir)
    nsp_path = download(nsp, nsp_dir)

    first = price_dir / prices[0].filename
    last = price_dir / prices[-1].filename
    print()
    print(f"prices {len(prices)} files: {prices[0].filename} .. {prices[-1].filename}")
    print(f"nsp    {nsp.filename}")
    print(f"header prices: {peek_header(first)}")
    print(f"header nsp:    {peek_header(nsp_path)}")
    if last != first:
        print(f"header last:   {peek_header(last)}")
    interim = sum(1 for blob in prices if blob.filename.endswith("_I.csv"))
    if interim:
        print(f"note   {interim} day(s) still interim (_I); finals replace these later.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
