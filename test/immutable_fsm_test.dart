import 'package:immutable_fsm/immutable_fsm.dart';
import 'package:test/test.dart';

void main() {
  group('Immutable FSM', () {
    test(
      'Transitioning between states',
      _testSuccessfulTransitions,
    );
    test(
      'Multiple outbound transitions from a single state',
      _testMultipleOutboundPaths,
    );
    test(
      'Transitions between more than one state via emitting an event in onEnter',
      _testMultiStateTransition,
    );
    test(
      'Autostart the FSM by initiating the transition from the initial '
      'state after the FSM definition',
      _testAutostartTransition,
    );
    test(
      'Transition from a state to itself',
      _testTransitionToSelf,
    );
    test(
      'Equality check - same state and data, different definition order',
      _testEqualityEqual,
    );
    test(
      'Equality check - same configuration and data - different initial state',
      _testEqualityDifferent,
    );
    test(
      'Equality check - same configuration and state - different data',
      _testEqualityDifferentData,
    );
    test(
      'Ensure data emitted in onExit gets saved',
      _testDataEmittanceInOnExit,
    );
    test(
      'Transition attempt with no defined path',
      _testUndefinedPath,
    );
  });
}

/// Verifies successful transition between states when all events
/// are defined.
Future<void> _testSuccessfulTransitions() async {
  ImmutableFSM<_TestEvent, String> sut = _make2StateFSM();

  expect(
    sut.state,
    isA<_TestStateA>(),
    reason: 'FSM is expected to start at TestStateA',
  );

  final ImmutableFSM<_TestEvent, String> sutCopy =
      await sut.tryTransition(event: _TestEvent.goToB);

  expect(
    sutCopy,
    isNot(equals(sut)),
    reason: 'FSM is expected to produce a modified copy on transition',
  );

  expect(
    sutCopy.state,
    isA<_TestStateB>(),
    reason: 'FSM is expected to transition at TestStateB on `goToB` event',
  );

  sut = await sutCopy.tryTransition(event: _TestEvent.goToA);

  expect(
    sut.state,
    isA<_TestStateA>(),
    reason: 'FSM is expected to transition back to TestStateA on `goToA` event',
  );
}

/// Verifies successful transition between states when multiple events
/// lead from one state to two different states.
Future<void> _testMultipleOutboundPaths() async {
  final ImmutableFSM<_TestEvent, String> sut = _makeAtoBandCFSM();

  ImmutableFSM<_TestEvent, String> sutCopy =
      await sut.tryTransition(event: _TestEvent.goToB);

  expect(
    sutCopy.state,
    isA<_TestStateB>(),
    reason: 'FSM is expected to transition from A to B on `goToB` event',
  );

  sutCopy = await sut.tryTransition(event: _TestEvent.goToC);

  expect(
    sutCopy.state,
    isA<_TestStateC>(),
    reason: 'FSM is expected to transition form A to C on `goToC` event',
  );
}

/// Verifies transition between multiple states at the same time.
///
/// This happens when upon entering a state, it emits an additional event that
/// has a defined path, so FSM continues to follow that path.
Future<void> _testMultiStateTransition() async {
  final ImmutableFSM<_TestEvent, String> sut = _makeCDAFSM();
  expect(
    sut.state,
    isA<_TestStateC>(),
    reason: 'FSM is expected to start in state C',
  );

  final ImmutableFSM<_TestEvent, String> sutCopy =
      await sut.tryTransition(event: _TestEvent.goToD);

  expect(
    sutCopy.state,
    isA<_TestStateA>(),
    reason: 'FSM is expected to transition from C to A (through D).',
  );

  expect(
    sutCopy.data,
    'State D entered',
    reason: 'FSM is expected to produce output data while in state D',
  );
}

/// Verifies that calling [ImmutableFSM.tryTransition] right after the
/// definition allows to autostart the sequence.
Future<void> _testAutostartTransition() async {
  final ImmutableFSM<_TestEvent, String> sut = await _makeFSMWithAutostart();

  expect(
    sut.state,
    isA<_TestStateA>(),
    reason: 'FSM is expected to already be in state A upon start',
  );

  expect(
    sut.data,
    'State D entered',
    reason: 'FSM is expected to produce output data while moving '
        'through state D on startup',
  );
}

/// Verifies that transitioning from a state to itself (without modifying
/// the data) keeps the new FSM copy identical to the original.
Future<void> _testTransitionToSelf() async {
  final ImmutableFSM<_TestEvent, String> sut =
      const ImmutableFSM<_TestEvent, String>(
    initialState: _TestStateA(),
    data: 'test',
  ).addTransition(
    to: const _TestStateA(),
    from: const _TestStateA(),
    event: _TestEvent.goToA,
  );

  expect(
    await sut.tryTransition(event: _TestEvent.goToA),
    equals(sut),
    reason: 'Transitioning to the same state (with same data) '
        'is not expected to modify the FSM',
  );
}

/// Verifies that if two FSMs are defined with the same data, but the
/// definition happens in different order, the two FSM are still deemed equal.
Future<void> _testEqualityEqual() async {
  // First FSM - Initial state A, transitions from A to B to A
  final ImmutableFSM<_TestEvent, String> fsm1 =
      const ImmutableFSM<_TestEvent, String>(
    initialState: _TestStateA(),
    data: '',
  )
          .addTransition(
            from: const _TestStateA(),
            to: const _TestStateB(),
            event: _TestEvent.goToB,
          )
          .addTransition(
            from: const _TestStateB(),
            to: const _TestStateA(),
            event: _TestEvent.goToA,
          );

  // Second FSM - Initial state A, transitions from B to A to B
  // (different definition order).
  final ImmutableFSM<_TestEvent, String> fsm2 =
      const ImmutableFSM<_TestEvent, String>(
    initialState: _TestStateA(),
    data: '',
  )
          .addTransition(
            from: const _TestStateB(),
            to: const _TestStateA(),
            event: _TestEvent.goToA,
          )
          .addTransition(
            from: const _TestStateA(),
            to: const _TestStateB(),
            event: _TestEvent.goToB,
          );

  expect(
    fsm1,
    equals(fsm2),
    reason: 'Two FSMs are supposed to be equal, '
        'regardless of the definition order',
  );
  expect(
    fsm1.hashCode,
    fsm2.hashCode,
    reason: 'Two FSMs are supposed to have identical hashCode, '
        'regardless of the definition order',
  );
}

/// Verifies that if two FSMs are defined the same, but their
/// state is different, the two FSM are deemed different.
Future<void> _testEqualityDifferent() async {
  final ImmutableFSM<_TestEvent, String> fsm1 = _make2StateFSM();
  final ImmutableFSM<_TestEvent, String> fsm2 = _make2StateFSM(
    initialState: const _TestStateB(),
  );

  expect(
    fsm1,
    isNot(equals(fsm2)),
    reason: 'Two FSMs are supposed to be different, '
        'when their state is different',
  );

  expect(
    fsm1.hashCode,
    isNot(equals(fsm2.hashCode)),
    reason: 'Two FSMs are supposed to have different hashCode, '
        'when their state is different',
  );
}

/// Verifies that if two FSMs are defined the same, in the same state,
/// but their data is different, the two FSM are deemed different.
Future<void> _testEqualityDifferentData() async {
  final ImmutableFSM<_TestEvent, String> fsm1 =
      const ImmutableFSM<_TestEvent, String>(initialState: _TestStateE())
          .addTransition(
    from: const _TestStateE(),
    to: const _TestStateE(),
    event: _TestEvent.goToE,
  );

  final ImmutableFSM<_TestEvent, String> fsm2 =
      await fsm1.tryTransition(event: _TestEvent.goToE, data: 'Test');

  expect(fsm1.data, isNull, reason: 'First FSM is not expected to have data');
  expect(fsm2.data, 'Test', reason: 'Second FSM is expected to have test data');

  expect(
    fsm1.state,
    fsm2.state,
    reason: 'Both FSMs are expected to be in the same state',
  );

  expect(
    fsm1,
    isNot(equals(fsm2)),
    reason: 'Two FSMs are supposed to be different, '
        'when their data is different',
  );

  expect(
    fsm1.hashCode,
    isNot(equals(fsm2.hashCode)),
    reason: 'Two FSMs are supposed to have different hashCode, '
        'when their data is different',
  );
}

/// Verifies
Future<void> _testDataEmittanceInOnExit() async {
  final ImmutableFSM<_TestEvent, String> sut =
      const ImmutableFSM<_TestEvent, String>(
    initialState: _TestStateF(),
    data: '',
  ).addTransition(
    from: const _TestStateF(),
    to: const _TestStateA(),
    event: _TestEvent.goToA,
  );

  expect(sut.data, '', reason: 'FSM expect to carry no metadata on start');

  final ImmutableFSM<_TestEvent, String> resultingSut =
      await sut.tryTransition(event: _TestEvent.goToA);

  expect(
    resultingSut.data,
    'Left state F',
    reason: 'FSM is expected to contain the data emitted by state F',
  );
}

/// Verifies event handling when the path is not defined.
Future<void> _testUndefinedPath() async {
  final ImmutableFSM<_TestEvent, String> sut = _make2StateFSM();

  expect(
    () async => sut.tryTransition(event: _TestEvent.goToC),
    throwsA(isA<FSMException>()),
    reason: 'FSM is expected to throw FSMException when attempting '
        'to transition via undefined path',
  );
}

ImmutableFSM<_TestEvent, String> _make2StateFSM({
  _TestState initialState = const _TestStateA(),
}) =>
    ImmutableFSM<_TestEvent, String>(
      initialState: initialState,
      data: '',
    )
        .addTransition(
          from: const _TestStateA(),
          to: const _TestStateB(),
          event: _TestEvent.goToB,
        )
        .addTransition(
          from: const _TestStateB(),
          to: const _TestStateA(),
          event: _TestEvent.goToA,
        );

ImmutableFSM<_TestEvent, String> _makeAtoBandCFSM() =>
    const ImmutableFSM<_TestEvent, String>(
      initialState: _TestStateA(),
      data: '',
    )
        .addTransition(
          from: const _TestStateA(),
          to: const _TestStateB(),
          event: _TestEvent.goToB,
        )
        .addTransition(
          from: const _TestStateA(),
          to: const _TestStateC(),
          event: _TestEvent.goToC,
        );

ImmutableFSM<_TestEvent, String> _makeCDAFSM() =>
    const ImmutableFSM<_TestEvent, String>(
      initialState: _TestStateC(),
      data: '',
    )
        .addTransition(
          from: const _TestStateC(),
          to: const _TestStateD(),
          event: _TestEvent.goToD,
        )
        .addTransition(
          from: const _TestStateD(),
          to: const _TestStateA(),
          event: _TestEvent.goToA,
        );

Future<ImmutableFSM<_TestEvent, String>> _makeFSMWithAutostart() async =>
    _makeCDAFSM().tryTransition(event: _TestEvent.goToD);

enum _TestEvent {
  goToB,
  goToA,
  goToC,
  goToD,
  goToE,
}

typedef _TestState = FSMState<_TestEvent, String>;

class _TestStateA extends _TestState {
  const _TestStateA();
}

class _TestStateB extends _TestState {
  const _TestStateB();
}

class _TestStateC extends _TestState {
  const _TestStateC();
}

class _TestStateD extends _TestState {
  const _TestStateD();

  @override
  Future<void> onEnter(
    String? data, {
    required FSMStateOnEnterResponse<_TestEvent, String> response,
  }) async {
    response
      ..emitData('State D entered')
      ..emitEvent(_TestEvent.goToA);
  }
}

class _TestStateE extends _TestState {
  const _TestStateE();
}

class _TestStateF extends _TestState {
  const _TestStateF();

  @override
  Future<void> onExit(
    String? data, {
    required FSMStateOnExitResponse<_TestEvent, String> response,
  }) async =>
      response.emitData('Left state F');
}
