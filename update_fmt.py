import json, os
p = os.path.join(os.environ["USERPROFILE"], "Documents", "Projects", "Coding", "Roblox Tron Game", "default.project.json")
d = {
    "name": "Roblox Tron Game",
    "tree": {
        "$className": "DataModel",
        "ReplicatedStorage": {
            "TurnEvent": {"$className": "RemoteEvent"},
            "StateUpdate": {"$className": "UnreliableRemoteEvent"},
            "DeathEvent": {"$className": "RemoteEvent"},
            "ReplicateTurn": {"$className": "RemoteEvent"},
            "RestartEvent": {"$className": "RemoteEvent"},
            "SpawnSync": {"$className": "RemoteEvent"},
            "VictoryEvent": {"$className": "RemoteEvent"},
            "Shared": {"$path": "src/shared"}
        },
        "ServerScriptService": {
            "Server": {"$path": "src/server"}
        },
        "StarterPlayer": {
            "StarterPlayerScripts": {
                "Client": {"$path": "src/client"}
            }
        },
        "Workspace": {
            "$properties": {"FilteringEnabled": True},
            "Baseplate": {
                "$className": "Part",
                "$properties": {
                    "Anchored": True,
                    "CanCollide": True,
                    "Locked": True,
                    "Color": [0.384, 0.369, 0.384],
                    "Position": [0, -10, 0],
                    "Size": [1024, 20, 1024]
                }
            },
            "ArenaBounds": {
                "$className": "Folder",
                "Wall_North": {
                    "$className": "Part",
                    "$properties": {
                        "Anchored": True, "CanCollide": True, "Locked": True,
                        "Color": [0, 0.502, 1], "Material": "SmoothPlastic", "Transparency": 0,
                        "Size": [1024, 16, 4], "Position": [0, 8, -512]
                    }
                },
                "Wall_South": {
                    "$className": "Part",
                    "$properties": {
                        "Anchored": True, "CanCollide": True, "Locked": True,
                        "Color": [0, 0.502, 1], "Material": "SmoothPlastic", "Transparency": 0,
                        "Size": [1024, 16, 4], "Position": [0, 8, 512]
                    }
                },
                "Wall_East": {
                    "$className": "Part",
                    "$properties": {
                        "Anchored": True, "CanCollide": True, "Locked": True,
                        "Color": [0, 0.502, 1], "Material": "SmoothPlastic", "Transparency": 0,
                        "Size": [4, 16, 1024], "Position": [512, 8, 0]
                    }
                },
                "Wall_West": {
                    "$className": "Part",
                    "$properties": {
                        "Anchored": True, "CanCollide": True, "Locked": True,
                        "Color": [0, 0.502, 1], "Material": "SmoothPlastic", "Transparency": 0,
                        "Size": [4, 16, 1024], "Position": [-512, 8, 0]
                    }
                },
                "FloorLine_North": {
                    "$className": "Part",
                    "$properties": {
                        "Anchored": True, "CanCollide": True, "Locked": True,
                        "Color": [0, 0.502, 1], "Material": "SmoothPlastic", "Transparency": 0,
                        "Size": [1024, 1, 1], "Position": [0, 0.5, -512]
                    }
                },
                "FloorLine_South": {
                    "$className": "Part",
                    "$properties": {
                        "Anchored": True, "CanCollide": True, "Locked": True,
                        "Color": [0, 0.502, 1], "Material": "SmoothPlastic", "Transparency": 0,
                        "Size": [1024, 1, 1], "Position": [0, 0.5, 512]
                    }
                },
                "FloorLine_East": {
                    "$className": "Part",
                    "$properties": {
                        "Anchored": True, "CanCollide": True, "Locked": True,
                        "Color": [0, 0.502, 1], "Material": "SmoothPlastic", "Transparency": 0,
                        "Size": [1, 1, 1024], "Position": [512, 0.5, 0]
                    }
                },
                "FloorLine_West": {
                    "$className": "Part",
                    "$properties": {
                        "Anchored": True, "CanCollide": True, "Locked": True,
                        "Color": [0, 0.502, 1], "Material": "SmoothPlastic", "Transparency": 0,
                        "Size": [1, 1, 1024], "Position": [-512, 0.5, 0]
                    }
                }
            }
        },
        "Lighting": {
            "$properties": {
                "Ambient": [0, 0, 0],
                "Brightness": 2,
                "GlobalShadows": True,
                "Outlines": False,
                "Technology": "Voxel"
            }
        },
        "SoundService": {
            "$properties": {"RespectFilteringEnabled": True}
        }
    }
}
required = ["TurnEvent", "StateUpdate", "DeathEvent", "ReplicateTurn", "RestartEvent", "SpawnSync", "VictoryEvent"]
missing = [k for k in required if k not in d["tree"]["ReplicatedStorage"]]
if missing:
    raise SystemExit("ERROR: Missing remotes in project: " + ", ".join(missing))

with open(p, "w") as f: json.dump(d, f, separators=(",", ":"))
print("Updated to Rojo 7.x format")
