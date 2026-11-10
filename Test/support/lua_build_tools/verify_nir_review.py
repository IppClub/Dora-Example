from lua_tools import call
def verify_review(review, provenance, require_hash=True):
    return call('Tools.Godot.verify_nir_review', 'verify_review', review, provenance, require_hash)
