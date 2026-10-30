# ESP runtime implementation status

ESP.mm is a runtime prototype for the supplied app. A compiled ARM64 iOS dylib
and an unsigned IPA are in `out/`. Neither has been installed or tested in
Standoff 2. No anti-cheat changes are included.

Implemented source path:

- Resolve IL2CPP APIs using dlsym. All 18 required API names are present in
  UnityFramework's Mach-O export trie (`tools/verify_il2cpp_exports.py`).
  Runtime lookup after injection has not been tested.
- Resolve PlayerBindings from its assembly, obtain a System.Type, and invoke
  the non-generic Object.FindObjectsOfType(System.Type) overload.
- IL2CPP type registration confirms PlayerBindings (metadata type 15749)
  inherits UnityEngine.MonoBehaviour, so the Object search is type-compatible.
  Whether it finds every relevant player in a match remains untested.
- Resolve CharacterController -> Component.transform, then convert its local
  center and height endpoints through Transform.TransformPoint.
- Convert Unity Screen dimensions into overlay coordinates and draw rectangles.
- Root the array and camera during iteration with GC handles, check invocation
  exceptions and reject invalid/behind-camera projections. Updates run on the
  main run loop at a requested 20 Hz and process at most 128 bindings.
- Write a bounded local diagnostic log at `Documents/S2ESP-diagnostics.log`.
  It records library/overlay startup, runtime status, and aggregate player
  counts on state changes or every 15 seconds. It does not record account
  identifiers, challenge payloads, tokens, or player names.

`build.sh` was run in GitHub Actions run 40925862865, producing the older
`out/S2ESP.dylib` (72,120 bytes). The source now uses capsule dimensions and
TransformPoint and has not been rebuilt since that change.
`out/Standoff2-ESP-unsigned.ipa`
contains the older dylib and an executable load command for it. Archive CRC
and payload presence were checked; GBox signing, installation, constructor
execution and overlay display were not. A constructor registers an
app-activation observer and attempts installation in the active scene's key
window.

Device validation required: PlayerBindings discoverability, object lifetime,
all-enemy coverage, main-camera correctness, camera viewport/orientation,
self/team/dead-player filtering, actual character height, frame cost, app
integrity compatibility and GBox signing/install behavior. There is no
undetected or anti-ban claim.
The dylib load command can itself be detected; this build must not be treated
as safe for an account.

No runtime player offsets are used by this source. The separate static marker
analysis remains evidence for an alternate discovery path, not a validated
fallback implementation.
