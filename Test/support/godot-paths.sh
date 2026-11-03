# Shared by relocated Godot shell tests; the caller sets DORA_TEST_REPO.
ROOT="${DORA_ENGINE_ROOT:-${DORA_SSR_ROOT:-}}"
if [[ -z "$ROOT" ]]; then
    if [[ -f "$PWD/xmake.lua" ]]; then ROOT="$PWD";
    else ROOT="$(cd "$DORA_TEST_REPO/.." && pwd)/Dora-SSR"; fi
fi
[[ -f "$ROOT/xmake.lua" ]] || { echo 'Set DORA_ENGINE_ROOT to the engine checkout' >&2; exit 2; }
export DORA_ENGINE_ROOT="$ROOT" DORA_TEST_REPO
