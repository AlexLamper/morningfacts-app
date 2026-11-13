import importlib.util
spec=importlib.util.spec_from_file_location("a",".github/workflows/scripts/asc_lib.py");a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
v=[v for v in a.call("GET","/v1/apps/6833905431/appStoreVersions?filter[platform]=IOS")["data"] if v["attributes"]["versionString"]=="1.0"][0]
print("releaseType:",v["attributes"]["releaseType"],"state:",v["attributes"]["appStoreState"])
