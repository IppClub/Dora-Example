from lua_tools import call
MESA_COMMIT = '5005a50879b11b953ade113fccd13a208f706ba0'
MESA_SHA = '15a688666aca976d1479c8bd43d319a55613da9a91aaf42a07691daec96ba7be'
NIR_SHA = '21ba3c0532caa580b50c530aefc851686b747b41d7984c228bcc0cef7ef5db82'
def read_archive(path, expected, prefix): return call('Tools.Godot.generate_nir_notices', 'read_archive', path, expected, prefix, binary_values=True)
def comments(text): return call('Tools.Godot.generate_nir_notices', 'comments', text, list_result=True)
