## 1.2.0

### Breaking changes

- Raised the minimum Dart SDK to `3.12.0`, and updated dependencies to the latest versions. 

### Other changes

- Removed the `fast_immutable_collections` dependency, maintaining the FSM immutability. 
- Modernized `analysis_options.yaml` for the current analyzer.
- Updated source code formatting to match modern Dart.
- Fixed `tryTransition` to hand the metadata the FSM is carrying to
  `FSMState.onExit` and `FSMState.onEnter` when no `data` argument is passed.
  The handlers used to receive `null` on the first hop.
- Expanded the test suite, covering transition and data flow, and FSM definition, 
  equality and error paths.

## 1.1.0

- Updated `fast_immutable_collections` to `^11.0.0`.
- Shortened package description.

## 1.0.0

- Initial version.
