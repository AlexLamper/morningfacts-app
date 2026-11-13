#!/usr/bin/env python3
"""Push MorningFacts store assets to App Store Connect with the API key.

Idempotent: anything that already exists is skipped.
- iPhone 6.9" and iPad 13" screenshots for en-US and nl-NL (store_assets/)
- Dutch App Store listing (app info + version localization)
- App Review screenshot for every subscription and in-app purchase
- Dutch names for the subscription group, subscriptions and lifetime purchase
- Attaches the newest valid 1.0 build to the 1.0 version
"""

import base64
import glob
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request

import jwt

API = "https://api.appstoreconnect.apple.com"
APP_ID = os.environ.get("APP_ID", "6833905431")
GROUP_ID = os.environ.get("SUB_GROUP_ID", "22575622")
ROOT = os.environ.get("ASSETS_DIR", "store_assets")
PROBLEMS = []


def token():
    raw = os.environ["APP_STORE_CONNECT_API_KEY_P8"]
    key = raw if "BEGIN PRIVATE KEY" in raw else base64.b64decode(raw).decode()
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["APP_STORE_CONNECT_ISSUER_ID"], "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
        key, algorithm="ES256", headers={"kid": os.environ["APP_STORE_CONNECT_KEY_ID"]},
    )


TOKEN = token()


def call(method, path, body=None):
    url = path if path.startswith("http") else API + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {TOKEN}")
    if data:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as r:
            txt = r.read().decode()
            return json.loads(txt) if txt else {}
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"{method} {path} -> {e.code}: {e.read().decode()[:600]}")


def soft(label, fn):
    try:
        return fn()
    except Exception as e:  # keep going, report at the end
        print(f"!! {label}: {e}", flush=True)
        PROBLEMS.append(label)


def upload_file(create_path, rel_name, rel_type, rel_id, file_path, patch_path):
    blob = open(file_path, "rb").read()
    res = call("POST", create_path, {"data": {
        "type": create_path.rsplit("/", 1)[-1],
        "attributes": {"fileName": os.path.basename(file_path), "fileSize": len(blob)},
        "relationships": {rel_name: {"data": {"type": rel_type, "id": rel_id}}},
    }})
    obj = res["data"]
    for op in obj["attributes"]["uploadOperations"]:
        part = blob[op["offset"]: op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=part, method=op["method"])
        for h in op["requestHeaders"]:
            req.add_header(h["name"], h["value"])
        urllib.request.urlopen(req).read()
    call("PATCH", f"{patch_path}/{obj['id']}", {"data": {
        "type": obj["type"], "id": obj["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(blob).hexdigest()},
    }})
    print(f"   uploaded {file_path}", flush=True)


# ---------- texts ----------
NL = {
    "name": "MorningFacts: Leer elke dag",
    "subtitle": "Elke dag een klein feitje",
    "promo": "Elke keer dat je de app opent een klein feitje. Kies je onderwerpen en niveau en leer in minder dan een minuut iets nieuws.",
    "keywords": "feitjes,weetjes,leren,kennis,quiz,wist je dat,trivia,wetenschap,geschiedenis,ruimte,dagelijks",
    "description": """Leer elke dag iets nieuws - in minder dan een minuut.

MorningFacts geeft je elke keer dat je de app opent een kort feitje, gekozen uit de onderwerpen die jij leuk vindt en passend bij jouw niveau. Lees het, beantwoord een snelle vraag en klaar. Een kleine dagelijkse gewoonte, een flinke berg kennis.

HOE HET WERKT
- Kies 5 onderwerpen: ruimte, geschiedenis, natuur, het menselijk lichaam, wetenschap, aardrijkskunde en meer
- Kies je niveau: beginner, nieuwsgierig of expert
- Krijg elke dag een feitje, met een korte vraag zodat het blijft hangen
- Like of dislike feitjes, zodat MorningFacts leert wat jij leuk vindt
- Optionele ochtendherinnering, zodat je nooit een feitje mist

MORNINGFACTS PREMIUM
- Onbeperkt feitjes per dag
- Alle onderwerpen en niveaus
- Bewaar je favoriete feitjes
- Steun een onafhankelijke maker

Premium is er als jaarabonnement (met 7 dagen gratis), maandabonnement of eenmalige levenslange aankoop. Het gratis dagelijkse feitje blijft altijd gratis.

Beschikbaar in het Nederlands en Engels.

Geen account. Geen advertenties. Geen tracking. Je onderwerpen, likes en voortgang blijven op je telefoon.

Abonnementen worden automatisch verlengd, tenzij je minstens 24 uur voor het einde van de periode opzegt. De verlenging wordt binnen 24 uur voor het einde van de periode via je Apple ID afgeschreven. Beheer en zeg op in je App Store-instellingen.

Gebruiksvoorwaarden: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacybeleid: https://github.com/AlexLamper/morningfacts-app/blob/main/PRIVACY.md""",
}
SUPPORT = "https://github.com/AlexLamper/morningfacts-app/blob/main/SUPPORT.md"
PRIVACY = "https://github.com/AlexLamper/morningfacts-app/blob/main/PRIVACY.md"
NL_PRODUCTS = {
    "morningfacts_premium_yearly": ("Premium per jaar", "Onbeperkt feitjes, alle onderwerpen"),
    "morningfacts_premium_monthly": ("Premium per maand", "Onbeperkt feitjes, alle onderwerpen"),
}
NL_LIFETIME = ("Premium levenslang", "Eenmalig: onbeperkt feitjes voor altijd")

# ---------- version + localizations ----------
versions = call("GET", f"/v1/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=10")["data"]
version = next(v for v in versions if v["attributes"]["appStoreState"] in
               ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"))
vid = version["id"]
print(f"Version {version['attributes']['versionString']} ({vid})")

locs = {l["attributes"]["locale"]: l for l in call("GET", f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations")["data"]}
if "nl-NL" not in locs:
    def make_nl():
        r = call("POST", "/v1/appStoreVersionLocalizations", {"data": {
            "type": "appStoreVersionLocalizations",
            "attributes": {"locale": "nl-NL", "description": NL["description"], "keywords": NL["keywords"],
                           "promotionalText": NL["promo"], "supportUrl": SUPPORT},
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
        locs["nl-NL"] = r["data"]
        print("Created nl-NL version localization")
    soft("nl-NL version localization", make_nl)

infos = call("GET", f"/v1/apps/{APP_ID}/appInfos")["data"]
info = next((i for i in infos if i["attributes"].get("appStoreState") != "READY_FOR_SALE"), infos[0])
info_locs = {l["attributes"]["locale"] for l in call("GET", f"/v1/appInfos/{info['id']}/appInfoLocalizations")["data"]}
if "nl-NL" not in info_locs:
    soft("nl-NL app info", lambda: call("POST", "/v1/appInfoLocalizations", {"data": {
        "type": "appInfoLocalizations",
        "attributes": {"locale": "nl-NL", "name": NL["name"], "subtitle": NL["subtitle"], "privacyPolicyUrl": PRIVACY},
        "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info["id"]}}}}}) and print("Created nl-NL app info"))

# ---------- screenshots ----------
DISPLAY = {"iphone69": "APP_IPHONE_67", "ipad13": "APP_IPAD_PRO_3GEN_129"}
LANG = {"en": "en-US", "nl": "nl-NL"}
for device, dtype in DISPLAY.items():
    for short, locale in LANG.items():
        loc = locs.get(locale)
        files = sorted(glob.glob(f"{ROOT}/{device}/{short}/*.png"))
        if not loc or not files:
            continue

        def do_set(loc=loc, files=files, dtype=dtype, locale=locale):
            sets = call("GET", f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")["data"]
            s = next((x for x in sets if x["attributes"]["screenshotDisplayType"] == dtype), None)
            if not s:
                s = call("POST", "/v1/appScreenshotSets", {"data": {
                    "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": dtype},
                    "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"]}}}}})["data"]
            have = call("GET", f"/v1/appScreenshotSets/{s['id']}/appScreenshots")["data"]
            if have:
                print(f"{locale} {dtype}: already {len(have)} screenshots, skip")
                return
            print(f"{locale} {dtype}: uploading {len(files)}")
            for f in files:
                upload_file("/v1/appScreenshots", "appScreenshotSet", "appScreenshotSets", s["id"], f, "/v1/appScreenshots")
        soft(f"screenshots {locale} {dtype}", do_set)

# ---------- in-app purchase review screenshots + NL names ----------
REVIEW = f"{ROOT}/review/paywall.png"
subs = call("GET", f"/v1/subscriptionGroups/{GROUP_ID}/subscriptions")["data"]
for sub in subs:
    pid = sub["attributes"]["productId"]

    def sub_shot(sub=sub, pid=pid):
        cur = call("GET", f"/v1/subscriptions/{sub['id']}/appStoreReviewScreenshot").get("data")
        if cur:
            print(f"{pid}: review screenshot exists")
            return
        upload_file("/v1/subscriptionAppStoreReviewScreenshots", "subscription", "subscriptions", sub["id"], REVIEW,
                    "/v1/subscriptionAppStoreReviewScreenshots")
    soft(f"review screenshot {pid}", sub_shot)

    def sub_nl(sub=sub, pid=pid):
        have = {l["attributes"]["locale"] for l in call("GET", f"/v1/subscriptions/{sub['id']}/subscriptionLocalizations")["data"]}
        if "nl-NL" in have or pid not in NL_PRODUCTS:
            return
        name, desc = NL_PRODUCTS[pid]
        call("POST", "/v1/subscriptionLocalizations", {"data": {"type": "subscriptionLocalizations",
             "attributes": {"locale": "nl-NL", "name": name, "description": desc},
             "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sub["id"]}}}}})
        print(f"{pid}: nl-NL name added")
    soft(f"nl name {pid}", sub_nl)


def group_nl():
    have = {l["attributes"]["locale"] for l in call("GET", f"/v1/subscriptionGroups/{GROUP_ID}/subscriptionGroupLocalizations")["data"]}
    if "nl-NL" not in have:
        call("POST", "/v1/subscriptionGroupLocalizations", {"data": {"type": "subscriptionGroupLocalizations",
             "attributes": {"locale": "nl-NL", "name": "MorningFacts Premium", "customAppName": NL["name"]},
             "relationships": {"subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": GROUP_ID}}}}})
        print("Group nl-NL added")
soft("group nl", group_nl)

iaps = call("GET", f"/v1/apps/{APP_ID}/inAppPurchasesV2?limit=50")["data"]
for iap in iaps:
    pid = iap["attributes"]["productId"]

    def iap_shot(iap=iap, pid=pid):
        cur = call("GET", f"/v2/inAppPurchases/{iap['id']}/appStoreReviewScreenshot").get("data")
        if cur:
            print(f"{pid}: review screenshot exists")
            return
        upload_file("/v1/inAppPurchaseAppStoreReviewScreenshots", "inAppPurchaseV2", "inAppPurchases", iap["id"], REVIEW,
                    "/v1/inAppPurchaseAppStoreReviewScreenshots")
    soft(f"review screenshot {pid}", iap_shot)

    def iap_nl(iap=iap, pid=pid):
        have = {l["attributes"]["locale"] for l in call("GET", f"/v2/inAppPurchases/{iap['id']}/inAppPurchaseLocalizations")["data"]}
        if "nl-NL" in have:
            return
        call("POST", "/v1/inAppPurchaseLocalizations", {"data": {"type": "inAppPurchaseLocalizations",
             "attributes": {"locale": "nl-NL", "name": NL_LIFETIME[0], "description": NL_LIFETIME[1]},
             "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap["id"]}}}}})
        print(f"{pid}: nl-NL name added")
    soft(f"nl name {pid}", iap_nl)

# ---------- attach build ----------
def attach_build():
    vs = version["attributes"]["versionString"]
    builds = call("GET", f"/v1/builds?filter[app]={APP_ID}&filter[preReleaseVersion.version]={vs}"
                         f"&filter[processingState]=VALID&sort=-uploadedDate&limit=1")["data"]
    if not builds:
        all_b = call("GET", f"/v1/builds?filter[app]={APP_ID}&sort=-uploadedDate&limit=5&include=preReleaseVersion")
        print("No valid build for", vs, "- recent:", [(b["attributes"]["version"], b["attributes"]["processingState"]) for b in all_b["data"]])
        raise RuntimeError("no valid build")
    b = builds[0]
    call("PATCH", f"/v1/appStoreVersions/{vid}/relationships/build", {"data": {"type": "builds", "id": b["id"]}})
    print(f"Attached build {b['attributes']['version']} to {vs}")
soft("attach build", attach_build)

print("\nDONE" + (f" with problems: {PROBLEMS}" if PROBLEMS else " - all good"))
sys.exit(1 if PROBLEMS else 0)
