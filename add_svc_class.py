import json, os
p = os.path.join(os.environ["USERPROFILE"], "Documents", "Projects", "Coding", "Roblox Tron Game", "default.project.json")
with open(p) as f: d = json.load(f)
d["tree"] = {
    "$className": "DataModel",
    "ReplicatedStorage": {"$className": "ReplicatedStorage", "Shared": {"$path": "src/shared"}},
    "ServerScriptService": {"$className": "ServerScriptService", "Server": {"$path": "src/server"}},
    "StarterPlayer": {"$className": "StarterPlayer", "StarterPlayerScripts": {"Client": {"$path": "src/client"}}},
    "Workspace": {"$className": "Workspace", "Baseplate": {"$className": "Part", "Anchored": True, "CanCollide": True, "Locked": True, "Size": [1024, 20, 1024]}}
}
with open(p, "w") as f: json.dump(d, f, separators=(",", ":"))
print("Added classNames to services")