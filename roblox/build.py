# Собирает VillageWar.rbxlx из двух скриптов
import pathlib
d=pathlib.Path(__file__).parent
srv=(d/'GameServer.server.luau').read_text(); cli=(d/'Client.client.luau').read_text()
assert ']]>' not in srv+cli
x=f'''<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">
<Item class="Workspace" referent="RBX0"><Properties><string name="Name">Workspace</string></Properties></Item>
<Item class="ServerScriptService" referent="RBX1"><Properties><string name="Name">ServerScriptService</string></Properties>
<Item class="Script" referent="RBX2"><Properties><string name="Name">GameServer</string><ProtectedString name="Source"><![CDATA[{srv}]]></ProtectedString></Properties></Item>
</Item>
<Item class="StarterPlayer" referent="RBX3"><Properties><string name="Name">StarterPlayer</string></Properties>
<Item class="StarterPlayerScripts" referent="RBX4"><Properties><string name="Name">StarterPlayerScripts</string></Properties>
<Item class="LocalScript" referent="RBX5"><Properties><string name="Name">Client</string><ProtectedString name="Source"><![CDATA[{cli}]]></ProtectedString></Properties></Item>
</Item></Item>
</roblox>
'''
(d/'VillageWar.rbxlx').write_text(x,encoding='utf-8')
print('ok')
