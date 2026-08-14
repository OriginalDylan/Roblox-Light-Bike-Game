import json, os
p = os.path.join(os.environ["USERPROFILE"], "Documents", "Projects", "Coding", "Roblox Tron Game", "default.project.json")
with open(p) as f: d = json.load(f)
# Try flat format (Rojo 7.x style)
new_d = {
    "name": d["name"],
    "$className": "DataModel",
    "ReplicatedStorage": {"Shared": {"$path": "src/shared"}},
    "ServerScriptService": {"Server": {"$path": "src/server"}},
    "StarterPlayer": {"StarterPlayerScripts": {"Client": {"$path": "src/client"}}},
    "Workspace": {"Baseplate": {"$className": "Part", "Anchored": True, "CanCollide": True, "Locked": True, "Size": [1024, 20, 1024]}}
}
with open(p, "w") as f: json.dump(new_d, f, separators=(",", ":"))
print("Flat format")