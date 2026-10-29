# ESP runtime implementation status

ESP.mm is an uncompiled runtime prototype for the supplied app. It has not been
loaded into Standoff 2 and is not a ready IPA. No anti-cheat changes are included.

Implemented source path:

- Resolve IL2CPP APIs using dlsym. All 18 required API names were found among
  the binary's external symbols; export-trie visibility and runtime lookup have
  not been tested.
- Resolve PlayerBindings from its assembly, obtain a System.Type, and invoke
  the non-generic Object.FindObjectsOfType(System.Type) overload.
- Resolve CharacterController -> Component.transform -> Transform.position.
- Project a base point and an approximate 1.7m height through Camera.main.
- Convert Unity Screen dimensions into overlay coordinates and draw rectangles.
- Root the array and camera during iteration with GC handles, check invocation
  exceptions and reject invalid/behind-camera projections. Updates run on the
  main run loop at a requested 20 Hz and process at most 128 bindings.

Build on macOS with Xcode: bash build.sh. This command has not been executed
in the current Windows environment. Integrating the dylib, invoking
S2ESPInstall(UIWindow*) at the correct lifecycle point, packaging and signing
remain unverified. A constructor now registers an app-activation observer and
attempts installation in the active scene's key window. Repeated installation
checks avoid duplicate overlays. This startup code has not run on a device.
Copying the dylib into an app alone does not load it: a load-command integration
or equivalent supported loader step is still required.

Device validation required: PlayerBindings discoverability, object lifetime,
all-enemy coverage, main-camera correctness, camera viewport/orientation,
self/team/dead-player filtering, actual character height, frame cost, app
integrity compatibility and GBox signing/install behavior. There is no
undetected or anti-ban claim.

No runtime player offsets are used by this source. The separate static marker
analysis remains evidence for an alternate discovery path, not a validated
fallback implementation.
