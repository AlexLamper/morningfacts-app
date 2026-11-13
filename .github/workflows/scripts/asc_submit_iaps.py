#!/usr/bin/env python3
"""Attach the subscriptions and the lifetime purchase to the pending app review submission."""
import importlib.util, os, sys
os.environ.setdefault("ASC_ONLY_HELPERS", "1")
spec = importlib.util.spec_from_file_location("a", os.path.join(os.path.dirname(__file__), "asc_lib.py"))
a = importlib.util.module_from_spec(spec); spec.loader.exec_module(a)
APP_ID, GROUP_ID = "6833905431", "22575622"
bad = []
for s in a.call("GET", f"/v1/subscriptionGroups/{GROUP_ID}/subscriptions")["data"]:
    pid, state = s["attributes"]["productId"], s["attributes"]["state"]
    print(pid, state)
    if state in ("WAITING_FOR_REVIEW", "IN_REVIEW", "APPROVED"):
        continue
    try:
        a.call("POST", "/v1/subscriptionSubmissions", {"data": {"type": "subscriptionSubmissions",
               "relationships": {"subscription": {"data": {"type": "subscriptions", "id": s["id"]}}}}})
        print("  submitted")
    except Exception as e:
        print("  !!", e); bad.append(pid)
for i in a.call("GET", f"/v1/apps/{APP_ID}/inAppPurchasesV2")["data"]:
    pid, state = i["attributes"]["productId"], i["attributes"]["state"]
    print(pid, state)
    if state in ("WAITING_FOR_REVIEW", "IN_REVIEW", "APPROVED"):
        continue
    try:
        a.call("POST", "/v1/inAppPurchaseSubmissions", {"data": {"type": "inAppPurchaseSubmissions",
               "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": i["id"]}}}}})
        print("  submitted")
    except Exception as e:
        print("  !!", e); bad.append(pid)
print("DONE", bad or "all good"); sys.exit(1 if bad else 0)
