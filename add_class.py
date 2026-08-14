import json, os
p = os.path.join(os.environ['USERPROFILE'], 'Documents', 'Projects', 'Coding', 'Roblox Tron Game', 'default.project.json')
with open(p) as f: d = json.load(f)
d['tree'] = {'': 'DataModel', **d['tree']}
with open(p, 'w') as f: json.dump(d, f, separators=(',', ':'))
print('Added className')