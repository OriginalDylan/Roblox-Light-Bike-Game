import json, os
path = os.path.join(os.environ['USERPROFILE'], 'Documents', 'Projects', 'Coding', 'Roblox Tron Game', 'default.project.json')
with open(path, 'r') as f:
    data = json.load(f)

data['tree']['ServerScriptService'] = {
    'Server': {
        '\': 'src/server',
        'init.server': {
            '\': 'Script',
            '\': 'src/server/init.server.luau'
        }
    }
}

with open(path, 'w') as f:
    json.dump(data, f, indent=2)
print('Restructured')