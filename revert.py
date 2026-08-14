import json
p = r'C:\Users\Administrator.FRE-RDC-07\Documents\Projects\Coding\Roblox Tron Game\default.project.json'
with open(p) as f: d = json.load(f)

d['tree']['ServerScriptService'] = {
    'Server': {'`$path': 'src/server'}
}

with open(p, 'w') as f: json.dump(d, f, indent=2)
print('Reverted')