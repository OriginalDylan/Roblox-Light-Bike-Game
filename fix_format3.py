import json
p = r'C:\Users\Administrator.FRE-RDC-07\Documents\Projects\Coding\Roblox Tron Game\default.project.json'
with open(p, 'r') as f:
    d = json.load(f)
d['tree']['ServerScriptService'] = {'Server': {'\': 'src/server'}}
with open(p, 'w') as f:
    json.dump(d, f, separators=(',', ':'))
print('Fixed format')