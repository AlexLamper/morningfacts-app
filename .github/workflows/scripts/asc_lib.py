import base64, json, os, time, urllib.error, urllib.request
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


