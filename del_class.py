import json, os
p = os.path.join(os.environ['USERPROFILE'], 'Documents', 'Projects', 'Coding', 'Roblox Tron Game', 'default.project.json')
with open(p, 'r') as f: d = json.load(f)
del d['tree']['$className']
with open(p, 'w') as f: json.dump(d, f, separators=(',', ':'))
print('Removed root className')