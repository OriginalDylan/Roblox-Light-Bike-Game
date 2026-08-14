import json, os
p = os.path.join(os.environ['USERPROFILE'], 'Documents', 'Projects', 'Coding', 'Roblox Tron Game', 'default.project.json')
with open(p, 'r') as f: d = json.load(f)
d['tree']['Workspace'] = {'Baseplate': {'$className': 'Part', 'Anchored': True, 'CanCollide': True, 'Locked': True, 'Size': [1024, 20, 1024]}}
with open(p, 'w') as f: json.dump(d, f, separators=(',', ':'))
print('Fixed Workspace')