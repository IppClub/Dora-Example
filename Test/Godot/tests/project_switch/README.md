# Cross-project isolation fixtures

Run A → B → A with at most one active project. Both projects deliberately use
identical `res://` filenames and script class names, but different resources,
autoload identities and visible output. A leaves a pressed action and project-only
configuration behind; B must not inherit either or A's extra autoload.

A passing embedded implementation must verify fresh script static state, correct
resource/autoload identity, input-map cleanup, project settings and the absence of
old nodes. Later GPU acceptance must also reject frames and audio from the old
project after unload completion. These fixtures do not implement project switching.

The initial fixture-only baseline ran in separate native Godot 4.4.1 processes;
that proves their syntax and expected markers, not Dora's embedded Godot 4.6
switching behavior. Logs remain in the engine's `build/godot-project-switch-v1/`.

The current macOS driver is `Test/Godot/run_project_switch.py`. It uses
one ordinary Dora/LibGodot process, checks 2/3/4 buffers and source/PCK transitions,
user Engine singleton and time-scale reset, A's tone versus B's silence, duplicate
client refusal and recovery after rejecting a project with no main scene. The
fixtures were extended after the initial separate-process baseline above. No experimental environment variable is set. This
is a bounded macOS acceptance, not a claim about all projects or platforms.
