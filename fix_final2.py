import json, os
p = os.path.join(os.environ['USERPROFILE'], 'Documents', 'Projects', 'Coding', 'Roblox Tron Game', 'default.project.json')
with open(p, 'r', encoding='utf-8-sig') as f:
    d = json.load(f)
d['tree']['ServerScriptService'] = {'Server': {'$path': 'src/server'}}
with open(p, 'w', encoding='utf-8') as f:
    json.dump(d, f, separators=(',', ':'))
print('Fixed')