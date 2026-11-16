import 'package:immutable_fsm/immutable_fsm.dart';
import 'package:test/test.dart';

void main() {
  setUp(_calls.clear);

  group('Immutable FSM', () {
    test('Transitioning between states', _testSuccessfulTransitions);
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
    test('Transition from a state to itself', _testTransitionToSelf);
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
    test('Transition attempt with no defined path', _testUndefinedPath);
  });

  group('Immutable FSM definition, equality and errors', () {
    test(
      'an FSM that was never given a transition raises FSMException',
      _testNeverGivenTransition,
    );
    test(
      'a state that has no outgoing transitions raises FSMException',
      _testStateWithNoOutgoingTransitions,
    );
    test(
      'an event that is not defined for the current state raises FSMException',
      _testEventNotDefinedForCurrentState,
    );
    test(
      'a state without value equality cannot be used as a transition endpoint',
      _testNoValueEqualityCannotBeEndpoint,
    );
    test(
      'a state with value equality works as a transition endpoint even without const',
      _testValueEqualityWorksAsEndpoint,
    );
    test(
      're-registering the same (from, event) pair keeps the most recently registered target',
      _testReRegisteredTransitionKeepsLatestTarget,
    );
    test(
      'two different events from one state route to their own targets',
      _testDifferentEventsRouteToOwnTargets,
    );
    test(
      'addTransition does not modify the FSM it was called on',
      _testAddTransitionDoesNotModifyOriginal,
    );
    test(
      'addTransition preserves the current state and data',
      _testAddTransitionPreservesStateAndData,
    );
    test(
      'FSMs whose transition sets differ are not equal and hash differently',
      _testDifferentTransitionsNotEqual,
    );
    test(
      'definition order does not affect equality',
      _testDefinitionOrderDoesNotAffectEquality,
    );
    test(
      'equal FSMs collapse into a single Set entry',
      _testEqualFSMsCollapseInSet,
    );
    test('an FSM is not equal to a non-FSM', _testFSMNotEqualToNonFSM);
  });

  group('Immutable FSM transition and data flow', () {
    test(
      'onExit runs before onEnter, and each runs exactly once',
      _testOnExitBeforeOnEnter,
    );
    test(
      'the data passed to tryTransition reaches onExit, '
      'and the data emitted by onExit reaches onEnter',
      _testDataPassesThroughTransition,
    );
    test(
      'the data the FSM is carrying reaches the handlers '
      'when no data is passed',
      _testCarriedDataReachesHandlers,
    );
    test(
      'data emitted by onEnter overrides data emitted by onExit',
      _testOnEnterOverridesOnExit,
    );
    test(
      'the FSM\'s existing data survives a transition '
      'where nothing is emitted',
      _testDataSurvivesNoEmission,
    );
    test(
      'passing data explicitly replaces the FSM\'s data',
      _testDataReplacedByArgument,
    );
    test(
      'a state cannot clear data back to null '
      'when Data is itself nullable',
      _testDataNotClearableToNull,
    );
    test(
      'an event emitted from onExit does not start '
      'a chained transition',
      _testEventFromOnExitDiscarded,
    );
    test(
      'an event emitted from onEnter chains through '
      'every intermediate state in one tryTransition call',
      _testChainFromOnEnter,
    );
    test(
      'a chained transition whose event has no defined path '
      'aborts the whole call',
      _testBrokenChainAborts,
    );
    test(
      'awaiting asynchronous work inside a handler '
      'keeps the sequencing intact',
      _testAsyncHandlerSequence,
    );
    test(
      'a self transition that changes data returns a '
      'different FSM, one that changes nothing returns an equal FSM',
      _testSelfTransitionEquality,
    );
    test(
      'metadata stored by a state reaches the handlers of the next transition',
      _testStoredMetadataReachesNextTransition,
    );
    test(
      'a transition leaves the FSM it was called on untouched',
      _testOriginalFSMUntouched,
    );
  });
}

// ============================================================================
// Core transitions and equality
// ============================================================================

/// Verifies successful transition between states when all events
/// are defined.
Future<void> _testSuccessfulTransitions() async {
  ImmutableFSM<_TestEvent, String> sut = _make2StateFSM();

  expect(
    sut.state,
    isA<_TestStateA>(),
    reason: 'FSM is expected to start at TestStateA',
  );

  final ImmutableFSM<_TestEvent, String> sutCopy = await sut.tryTransition(
    event: _TestEvent.goToB,
  );

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

  ImmutableFSM<_TestEvent, String> sutCopy = await sut.tryTransition(
    event: _TestEvent.goToB,
  );

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

  final ImmutableFSM<_TestEvent, String> sutCopy = await sut.tryTransition(
    event: _TestEvent.goToD,
  );

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
    reason:
        'FSM is expected to produce output data while moving '
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
    reason:
        'Transitioning to the same state (with same data) '
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
    reason:
        'Two FSMs are supposed to be equal, '
        'regardless of the definition order',
  );
  expect(
    fsm1.hashCode,
    fsm2.hashCode,
    reason:
        'Two FSMs are supposed to have identical hashCode, '
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
    reason:
        'Two FSMs are supposed to be different, '
        'when their state is different',
  );

  expect(
    fsm1.hashCode,
    isNot(equals(fsm2.hashCode)),
    reason:
        'Two FSMs are supposed to have different hashCode, '
        'when their state is different',
  );
}

/// Verifies that if two FSMs are defined the same, in the same state,
/// but their data is different, the two FSM are deemed different.
Future<void> _testEqualityDifferentData() async {
  final ImmutableFSM<_TestEvent, String> fsm1 =
      const ImmutableFSM<_TestEvent, String>(
        initialState: _TestStateE(),
      ).addTransition(
        from: const _TestStateE(),
        to: const _TestStateE(),
        event: _TestEvent.goToE,
      );

  final ImmutableFSM<_TestEvent, String> fsm2 = await fsm1.tryTransition(
    event: _TestEvent.goToE,
    data: 'Test',
  );

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
    reason:
        'Two FSMs are supposed to be different, '
        'when their data is different',
  );

  expect(
    fsm1.hashCode,
    isNot(equals(fsm2.hashCode)),
    reason:
        'Two FSMs are supposed to have different hashCode, '
        'when their data is different',
  );
}

/// Verifies that data emitted by a state during [FSMState.onExit] ends up
/// as the metadata of the resulting FSM.
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

  final ImmutableFSM<_TestEvent, String> resultingSut = await sut.tryTransition(
    event: _TestEvent.goToA,
  );

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
    reason:
        'FSM is expected to throw FSMException when attempting '
        'to transition via undefined path',
  );
}

// ============================================================================
// Definition, equality and error paths
// ============================================================================

/// Verifies that an FSM that was never given a transition throws
/// [FSMException].
Future<void> _testNeverGivenTransition() async {
  const ImmutableFSM<_TestEvent, String> sut = ImmutableFSM<_TestEvent, String>(
    initialState: _TestStateA(),
  );

  await expectLater(
    sut.tryTransition(event: _TestEvent.goToB),
    throwsA(
      isA<FSMException>().having(
        (FSMException e) => e.message,
        'message',
        contains('No transition from'),
      ),
    ),
    reason:
        'An FSM with zero registered transitions has no path for any '
        'event, so tryTransition must throw FSMException',
  );
}

/// Verifies that a state with no outgoing transitions throws [FSMException].
Future<void> _testStateWithNoOutgoingTransitions() async {
  final ImmutableFSM<_TestEvent, String> sut =
      const ImmutableFSM<_TestEvent, String>(
        initialState: _TestStateB(),
        data: 'x',
      ).addTransition(
        from: const _TestStateA(),
        to: const _TestStateB(),
        event: _TestEvent.goToB,
      );
  await expectLater(
    sut.tryTransition(event: _TestEvent.goToC),
    throwsA(
      isA<FSMException>().having(
        (FSMException e) => e.message,
        'message',
        contains('No transition from'),
      ),
    ),
    reason:
        'Current state _TestStateB is absent from the transition map, '
        'so _transitions[state] is null and the guard in tryTransition '
        'throws FSMException',
  );
}

/// Verifies that an event not defined for the current state throws
/// [FSMException].
Future<void> _testEventNotDefinedForCurrentState() async {
  final ImmutableFSM<_TestEvent, String> sut =
      const ImmutableFSM<_TestEvent, String>(
        initialState: _TestStateA(),
        data: 'x',
      ).addTransition(
        from: const _TestStateA(),
        to: const _TestStateB(),
        event: _TestEvent.goToB,
      );
  await expectLater(
    sut.tryTransition(event: _TestEvent.goToD),
    throwsA(
      isA<FSMException>().having(
        (FSMException e) => e.message,
        'message',
        allOf(contains(_TestEvent.goToD.toString()), contains('_TestStateA')),
      ),
    ),
    reason:
        'The current state _TestStateA has a transition entry, but '
        '_TestEvent.goToD is not in that entry; the guard catches '
        'toState == null and throws FSMException mentioning the event '
        'and state type',
  );
}

/// Verifies that a state without value equality cannot be used as a
/// transition endpoint.
Future<void> _testNoValueEqualityCannotBeEndpoint() async {
  // The FSM state and the transition key have to be two *different*
  // instances, so neither one may be const-canonicalised into a single one.
  // ignore: prefer_const_constructors
  final _TestState state = _TestStateA();
  // ignore: prefer_const_constructors
  final _TestState key = _TestStateA();
  final ImmutableFSM<_TestEvent, String> baseSut =
      ImmutableFSM<_TestEvent, String>(initialState: state, data: 'x');
  final ImmutableFSM<_TestEvent, String> extended = baseSut.addTransition(
    from: key,
    to: const _TestStateB(),
    event: _TestEvent.goToB,
  );
  expect(
    extended,
    isNot(equals(baseSut)),
    reason:
        'addTransition returns a new FSM even though the state key '
        'does not match the initial state instance',
  );
  await expectLater(
    extended.tryTransition(event: _TestEvent.goToB),
    throwsA(
      isA<FSMException>().having(
        (FSMException e) => e.message,
        'message',
        contains('No transition from'),
      ),
    ),
    reason:
        'The _TestStateA instance used as the map key does not equal '
        'the FSM current-state instance (no == override), so '
        '_transitions[state] returns null and FSMException is raised',
  );
}

/// Verifies that a state with value equality works as a transition endpoint
/// even without a const constructor.
Future<void> _testValueEqualityWorksAsEndpoint() async {
  final ImmutableFSM<_TestEvent, String> sut =
      ImmutableFSM<_TestEvent, String>(
        initialState: _TestStateG(),
        data: 'x',
      ).addTransition(
        from: _TestStateG(),
        to: const _TestStateB(),
        event: _TestEvent.goToB,
      );
  final ImmutableFSM<_TestEvent, String> result = await sut.tryTransition(
    event: _TestEvent.goToB,
  );
  expect(
    result.state,
    isA<_TestStateB>(),
    reason:
        'State with value equality acts as a proper map key so the '
        'transition resolves and lands on _TestStateB',
  );
}

/// Verifies that re-registering the same transition keeps the most recently
/// registered target.
Future<void> _testReRegisteredTransitionKeepsLatestTarget() async {
  final ImmutableFSM<_TestEvent, String> sut =
      const ImmutableFSM<_TestEvent, String>(
            initialState: _TestStateA(),
            data: 'x',
          )
          .addTransition(
            from: const _TestStateA(),
            to: const _TestStateB(),
            event: _TestEvent.goToB,
          )
          .addTransition(
            from: const _TestStateA(),
            to: const _TestStateC(),
            event: _TestEvent.goToB,
          );
  final ImmutableFSM<_TestEvent, String> result = await sut.tryTransition(
    event: _TestEvent.goToB,
  );
  expect(
    result.state,
    isA<_TestStateC>(),
    reason:
        'Re-registering the same (from, event) pair replaces the '
        'target; the most recently registered target (_TestStateC) wins',
  );
}

/// Verifies that two different events from one state route to their own
/// targets.
Future<void> _testDifferentEventsRouteToOwnTargets() async {
  final ImmutableFSM<_TestEvent, String> sut =
      const ImmutableFSM<_TestEvent, String>(
            initialState: _TestStateA(),
            data: 'x',
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
  final ImmutableFSM<_TestEvent, String> resultB = await sut.tryTransition(
    event: _TestEvent.goToB,
  );
  expect(
    resultB.state,
    isA<_TestStateB>(),
    reason: '_TestEvent.goToB is routed to _TestStateB',
  );
  final ImmutableFSM<_TestEvent, String> resultC = await sut.tryTransition(
    event: _TestEvent.goToC,
  );
  expect(
    resultC.state,
    isA<_TestStateC>(),
    reason: '_TestEvent.goToC is routed to _TestStateC',
  );
}

/// Verifies that [ImmutableFSM.addTransition] does not modify the FSM it was
/// called on.
Future<void> _testAddTransitionDoesNotModifyOriginal() async {
  final ImmutableFSM<_TestEvent, String> original =
      const ImmutableFSM<_TestEvent, String>(
        initialState: _TestStateA(),
        data: 'x',
      ).addTransition(
        from: const _TestStateA(),
        to: const _TestStateB(),
        event: _TestEvent.goToB,
      );
  // Derived from `original`, so this must be the ONLY difference between
  // the two FSMs.
  final ImmutableFSM<_TestEvent, String> extended = original.addTransition(
    from: const _TestStateB(),
    to: const _TestStateC(),
    event: _TestEvent.goToC,
  );
  await expectLater(
    original.tryTransition(event: _TestEvent.goToC),
    throwsA(isA<FSMException>()),
    reason:
        'addTransition returns a new FSM; the route it registers must '
        'stay invisible to the instance it was called on',
  );
  // The copy carries the pre-existing route *and* the new one, so it walks
  // the whole way to _TestStateC.
  final ImmutableFSM<_TestEvent, String> firstHop = await extended
      .tryTransition(event: _TestEvent.goToB);
  final ImmutableFSM<_TestEvent, String> secondHop = await firstHop
      .tryTransition(event: _TestEvent.goToC);
  expect(
    secondHop.state,
    isA<_TestStateC>(),
    reason:
        'The copy keeps the inherited route and gains the new one, '
        'so it reaches _TestStateC',
  );
}

/// Verifies that [ImmutableFSM.addTransition] preserves the current state
/// and data.
Future<void> _testAddTransitionPreservesStateAndData() async {
  final ImmutableFSM<_TestEvent, String> original =
      const ImmutableFSM<_TestEvent, String>(
        initialState: _TestStateA(),
        data: 'persist',
      ).addTransition(
        from: const _TestStateA(),
        to: const _TestStateB(),
        event: _TestEvent.goToB,
      );
  final ImmutableFSM<_TestEvent, String> stepTwo = original.addTransition(
    from: const _TestStateB(),
    to: const _TestStateC(),
    event: _TestEvent.goToC,
  );
  expect(
    original.state,
    isA<_TestStateA>(),
    reason: 'The original FSM keeps its initial state after addTransition',
  );
  expect(
    original.data,
    equals('persist'),
    reason: 'The original FSM keeps its data after addTransition',
  );
  expect(
    stepTwo.state,
    isA<_TestStateA>(),
    reason: 'The extended FSM also retains the initial state',
  );
  expect(
    stepTwo.data,
    equals('persist'),
    reason: 'The extended FSM also retains the data',
  );
  expect(
    identical(stepTwo, original),
    isFalse,
    reason: 'addTransition returns a distinct instance',
  );
}

/// Verifies that FSMs whose transition sets differ are not equal and hash
/// differently.
Future<void> _testDifferentTransitionsNotEqual() async {
  final ImmutableFSM<_TestEvent, String> fsm1 =
      const ImmutableFSM<_TestEvent, String>(
        initialState: _TestStateA(),
        data: 'x',
      ).addTransition(
        from: const _TestStateA(),
        to: const _TestStateB(),
        event: _TestEvent.goToB,
      );
  final ImmutableFSM<_TestEvent, String> fsm2 =
      const ImmutableFSM<_TestEvent, String>(
        initialState: _TestStateA(),
        data: 'x',
      ).addTransition(
        from: const _TestStateA(),
        to: const _TestStateC(),
        event: _TestEvent.goToB,
      );
  expect(
    fsm1,
    isNot(equals(fsm2)),
    reason: 'FSMs with different transition sets are not equal',
  );
  expect(
    fsm1.hashCode,
    isNot(equals(fsm2.hashCode)),
    reason: 'FSMs with different transition sets produce different hashCodes',
  );
}

/// Verifies that the definition order of transitions does not affect
/// equality.
Future<void> _testDefinitionOrderDoesNotAffectEquality() async {
  final ImmutableFSM<_TestEvent, String> fsm1 =
      const ImmutableFSM<_TestEvent, String>(
            initialState: _TestStateA(),
            data: 'y',
          )
          .addTransition(
            from: const _TestStateA(),
            to: const _TestStateB(),
            event: _TestEvent.goToB,
          )
          .addTransition(
            from: const _TestStateB(),
            to: const _TestStateC(),
            event: _TestEvent.goToC,
          );
  final ImmutableFSM<_TestEvent, String> fsm2 =
      const ImmutableFSM<_TestEvent, String>(
            initialState: _TestStateA(),
            data: 'y',
          )
          .addTransition(
            from: const _TestStateB(),
            to: const _TestStateC(),
            event: _TestEvent.goToC,
          )
          .addTransition(
            from: const _TestStateA(),
            to: const _TestStateB(),
            event: _TestEvent.goToB,
          );
  expect(
    fsm1,
    equals(fsm2),
    reason: 'The same two transitions in opposite order produce equal FSMs',
  );
  expect(
    fsm1.hashCode,
    equals(fsm2.hashCode),
    reason: 'Equal FSMs have equal hashCodes regardless of definition order',
  );
}

/// Verifies that equal FSMs collapse into a single set entry.
Future<void> _testEqualFSMsCollapseInSet() async {
  final ImmutableFSM<_TestEvent, String> fsm1 =
      const ImmutableFSM<_TestEvent, String>(
            initialState: _TestStateA(),
            data: 'z',
          )
          .addTransition(
            from: const _TestStateA(),
            to: const _TestStateB(),
            event: _TestEvent.goToB,
          )
          .addTransition(
            from: const _TestStateB(),
            to: const _TestStateC(),
            event: _TestEvent.goToC,
          );
  final ImmutableFSM<_TestEvent, String> fsm2 =
      const ImmutableFSM<_TestEvent, String>(
            initialState: _TestStateA(),
            data: 'z',
          )
          .addTransition(
            from: const _TestStateB(),
            to: const _TestStateC(),
            event: _TestEvent.goToC,
          )
          .addTransition(
            from: const _TestStateA(),
            to: const _TestStateB(),
            event: _TestEvent.goToB,
          );
  final ImmutableFSM<_TestEvent, String> fsm3 =
      const ImmutableFSM<_TestEvent, String>(
        initialState: _TestStateA(),
        data: 'z',
      ).addTransition(
        from: const _TestStateA(),
        to: const _TestStateC(),
        event: _TestEvent.goToB,
      );
  final Set<ImmutableFSM<_TestEvent, String>> set =
      <ImmutableFSM<_TestEvent, String>>{fsm1, fsm2, fsm3};
  expect(
    set.length,
    equals(2),
    reason:
        'The two equal FSMs collapse into one Set entry; fsm3 differs, '
        'so the set has exactly 2 elements',
  );
}

/// Verifies that an FSM is not equal to a non-FSM.
///
/// The reflexive case (`sut == sut`) is deliberately not asserted: it holds
/// for any object through identity equality and would pass even without an
/// `==` override on [ImmutableFSM].
Future<void> _testFSMNotEqualToNonFSM() async {
  const ImmutableFSM<_TestEvent, String> sut = ImmutableFSM<_TestEvent, String>(
    initialState: _TestStateA(),
    data: 's',
  );
  expect(
    'not an fsm',
    isNot(equals(sut)),
    reason: 'A plain String is not equal to an FSM instance',
  );
}

// ============================================================================
// Transition and data flow
// ============================================================================

/// Verifies that [FSMState.onExit] runs before [FSMState.onEnter], and each
/// runs exactly once.
Future<void> _testOnExitBeforeOnEnter() async {
  final ImmutableFSM<_TestEvent, String> sut = _makeFlowFSM();
  await sut.tryTransition(event: _TestEvent.goToB);
  expect(
    _calls.length,
    2,
    reason: 'exactly one onExit and one onEnter call expected',
  );
  expect(
    _calls[0],
    contains('A.onExit'),
    reason: 'onExit of source state must run first',
  );
  expect(
    _calls[1],
    contains('B.onEnter'),
    reason: 'onEnter of target state must run second',
  );
}

/// Verifies that the data passed to [ImmutableFSM.tryTransition] reaches
/// [FSMState.onExit], and its emitted data reaches [FSMState.onEnter].
Future<void> _testDataPassesThroughTransition() async {
  final ImmutableFSM<_TestEvent, String> sut =
      const ImmutableFSM<_TestEvent, String>(
        initialState: _TestStateF(),
        data: 'carried',
      ).addTransition(
        from: const _TestStateF(),
        to: const _TestStateB(),
        event: _TestEvent.goToA,
      );
  await sut.tryTransition(event: _TestEvent.goToA, data: 'passed');
  expect(
    _calls,
    contains('F.onExit(passed)'),
    reason: 'data argument to tryTransition reaches onExit',
  );
  expect(
    _calls,
    contains('B.onEnter(Left state F)'),
    reason: 'data emitted by onExit reaches onEnter',
  );
}

/// Verifies that the data the FSM is carrying reaches the handlers when no
/// data is passed to [ImmutableFSM.tryTransition].
Future<void> _testCarriedDataReachesHandlers() async {
  final ImmutableFSM<_TestEvent, String> sut = _makeFlowFSM();
  await sut.tryTransition(event: _TestEvent.goToB);
  expect(
    _calls[0],
    'A.onExit(carried)',
    reason:
        'with no data argument, the metadata the FSM is carrying is '
        'passed to the states it leaves and enters',
  );
}

/// Verifies that data emitted by [FSMState.onEnter] overrides data emitted
/// by [FSMState.onExit].
Future<void> _testOnEnterOverridesOnExit() async {
  final ImmutableFSM<_TestEvent, String> sut =
      const ImmutableFSM<_TestEvent, String>(
        initialState: _TestStateF(),
        data: 'carried',
      ).addTransition(
        from: const _TestStateF(),
        to: const _TestStateC(),
        event: _TestEvent.goToB,
      );
  final ImmutableFSM<_TestEvent, String> result = await sut.tryTransition(
    event: _TestEvent.goToB,
  );
  expect(
    result.data,
    'State C entered',
    reason: 'data emitted by onEnter overrides data emitted by onExit',
  );
}

/// Verifies that the FSM's existing data survives a transition where
/// nothing is emitted.
Future<void> _testDataSurvivesNoEmission() async {
  final ImmutableFSM<_TestEvent, String> fsm = _makeFlowFSM();
  final ImmutableFSM<_TestEvent, String> result = await fsm.tryTransition(
    event: _TestEvent.goToB,
  );
  expect(
    result.data,
    'carried',
    reason: 'FSM data is preserved when no handler emits new data',
  );
  expect(
    result.state,
    isA<_TestStateB>(),
    reason: 'state should have transitioned to plain target',
  );
}

/// Verifies that data passed explicitly replaces the FSM's data.
Future<void> _testDataReplacedByArgument() async {
  final ImmutableFSM<_TestEvent, String> fsm = _makeFlowFSM();
  final ImmutableFSM<_TestEvent, String> result = await fsm.tryTransition(
    event: _TestEvent.goToB,
    data: 'replaced',
  );
  expect(
    result.data,
    'replaced',
    reason: 'explicit data argument replaces the FSM\'s existing data',
  );
}

/// Verifies that a state cannot clear data back to `null`, even when the
/// data type itself is nullable.
Future<void> _testDataNotClearableToNull() async {
  final ImmutableFSM<_TestEvent, String?> fsm =
      const ImmutableFSM<_TestEvent, String?>(
        initialState: _TestStateH(),
        data: 'before',
      ).addTransition(
        from: const _TestStateH(),
        to: const _TestStateH(),
        event: _TestEvent.goToB,
      );
  final ImmutableFSM<_TestEvent, String?> result = await fsm.tryTransition(
    event: _TestEvent.goToB,
  );
  expect(
    result.data,
    'before',
    reason:
        '_copyWith falls back to previous data when emitted value is '
        'null, so a state can never clear data back to null',
  );
}

/// Verifies that an event emitted from [FSMState.onExit] does not start a
/// chained transition.
Future<void> _testEventFromOnExitDiscarded() async {
  final ImmutableFSM<_TestEvent, String> fsm =
      const ImmutableFSM<_TestEvent, String>(
            initialState: _TestStateF(),
            data: 'carried',
          )
          .addTransition(
            from: const _TestStateF(),
            to: const _TestStateB(),
            event: _TestEvent.goToB,
          )
          .addTransition(
            from: const _TestStateB(),
            to: const _TestStateC(),
            event: _TestEvent.goToC,
          );
  final ImmutableFSM<_TestEvent, String> result = await fsm.tryTransition(
    event: _TestEvent.goToB,
  );
  expect(
    result.state,
    isA<_TestStateB>(),
    reason: 'the event emitted from onExit is dropped by the reset',
  );
  expect(
    _calls,
    isNot(contains('C.onEnter')),
    reason: 'no chained transition from onExit should execute',
  );
}

/// Verifies that an event emitted from [FSMState.onEnter] chains through
/// every intermediate state in one [ImmutableFSM.tryTransition] call.
Future<void> _testChainFromOnEnter() async {
  final ImmutableFSM<_TestEvent, String> fsm =
      const ImmutableFSM<_TestEvent, String>(
            initialState: _TestStateA(),
            data: 'carried',
          )
          .addTransition(
            from: const _TestStateA(),
            to: const _TestStateD(),
            event: _TestEvent.goToB,
          )
          .addTransition(
            from: const _TestStateD(),
            to: const _TestStateA(),
            event: _TestEvent.goToA,
          );
  final ImmutableFSM<_TestEvent, String> result = await fsm.tryTransition(
    event: _TestEvent.goToB,
  );
  expect(
    result.state,
    isA<_TestStateA>(),
    reason: 'chained transition should complete in one tryTransition call',
  );
  expect(
    result.data,
    'State D entered',
    reason: 'data from final state onEnter is returned',
  );
  // Asserted as the ordered sequence of handlers, with the data payload
  // stripped: the payload is deliberately NOT pinned here (that behaviour is
  // covered by `_testCarriedDataReachesHandlers`), and comparing the raw
  // list would couple this chaining test to it. Comparing whole elements also
  // avoids `indexOf`, where a missing entry returns -1 and could satisfy an
  // index comparison without either handler having run.
  expect(
    _calls.map((String call) => call.split('(').first).toList(),
    <String>['A.onExit', 'D.onEnter', 'A.onEnter'],
    reason:
        'every state in the chain runs its handler, in order, '
        'within the single tryTransition call',
  );
}

/// Verifies that a chained transition whose event has no defined path aborts
/// the whole call.
Future<void> _testBrokenChainAborts() async {
  final ImmutableFSM<_TestEvent, String> fsm =
      const ImmutableFSM<_TestEvent, String>(
        initialState: _TestStateA(),
        data: 'carried',
      ).addTransition(
        from: const _TestStateA(),
        to: const _TestStateD(),
        event: _TestEvent.goToB,
      );
  await expectLater(
    fsm.tryTransition(event: _TestEvent.goToB),
    throwsA(isA<FSMException>()),
    reason: 'missing transition path should throw FSMException',
  );
  expect(
    fsm.state,
    isA<_TestStateA>(),
    reason: 'original FSM is unchanged after failed chained transition',
  );
}

/// Verifies that awaiting asynchronous work inside a handler keeps the
/// sequencing intact.
Future<void> _testAsyncHandlerSequence() async {
  final ImmutableFSM<_TestEvent, String> fsm = _makeFlowFSM();
  final ImmutableFSM<_TestEvent, String> result = await fsm.tryTransition(
    event: _TestEvent.goToB,
  );
  expect(
    result.state,
    isA<_TestStateB>(),
    reason: 'result FSM should already be on the final async target',
  );
  expect(
    result.data,
    'carried',
    reason: 'the call completes only after the awaited work inside onEnter',
  );
  expect(_calls[0], contains('A.onExit'), reason: 'onExit runs before onEnter');
  expect(
    _calls[1],
    contains('B.onEnter'),
    reason: 'onEnter of async target completes after exit',
  );
}

/// Verifies that a self transition that changes data returns a different
/// FSM, while one that changes nothing returns an equal FSM.
Future<void> _testSelfTransitionEquality() async {
  final ImmutableFSM<_TestEvent, String> fsm =
      const ImmutableFSM<_TestEvent, String>(
        initialState: _TestStateE(),
        data: 'carried',
      ).addTransition(
        from: const _TestStateE(),
        to: const _TestStateE(),
        event: _TestEvent.goToE,
      );
  final ImmutableFSM<_TestEvent, String> resultSame = await fsm.tryTransition(
    event: _TestEvent.goToE,
  );
  expect(
    resultSame,
    equals(fsm),
    reason: 'self transition without data change returns an equal FSM',
  );
  final ImmutableFSM<_TestEvent, String> resultDifferent = await fsm
      .tryTransition(event: _TestEvent.goToE, data: 'other');
  expect(
    resultDifferent,
    isNot(equals(fsm)),
    reason: 'self transition with data change returns a different FSM',
  );
}

/// Verifies that metadata stored by a state reaches the handlers of the next
/// transition.
Future<void> _testStoredMetadataReachesNextTransition() async {
  final ImmutableFSM<_TestEvent, String> fsm =
      const ImmutableFSM<_TestEvent, String>(initialState: _TestStateA())
          .addTransition(
            from: const _TestStateA(),
            to: const _TestStateC(),
            event: _TestEvent.goToB,
          )
          .addTransition(
            from: const _TestStateC(),
            to: const _TestStateB(),
            event: _TestEvent.goToC,
          );

  final ImmutableFSM<_TestEvent, String> stored = await fsm.tryTransition(
    event: _TestEvent.goToB,
  );
  expect(
    stored.data,
    'State C entered',
    reason: 'the state stored metadata as it was entered',
  );
  expect(
    _calls,
    contains('C.onEnter(null)'),
    reason:
        'nothing had been passed or stored yet, so this hop correctly '
        'receives null',
  );

  _calls.clear();
  final ImmutableFSM<_TestEvent, String> next = await stored.tryTransition(
    event: _TestEvent.goToC,
  );
  expect(
    _calls,
    contains('C.onExit(State C entered)'),
    reason:
        'metadata stored by a state must reach the handlers of the next '
        'transition, not merely be kept on the FSM',
  );
  expect(
    next.data,
    'State C entered',
    reason: 'the state being left emits nothing, so the metadata carries on',
  );
}

/// Verifies that a transition leaves the FSM it was called on untouched.
Future<void> _testOriginalFSMUntouched() async {
  final ImmutableFSM<_TestEvent, String> original = _makeFlowFSM();
  final ImmutableFSM<_TestEvent, String> result = await original.tryTransition(
    event: _TestEvent.goToB,
    data: 'passed',
  );
  expect(
    original.data,
    'carried',
    reason: 'original FSM is immutable and keeps its data',
  );
  expect(
    original.state,
    isA<_TestStateA>(),
    reason: 'original FSM is immutable and keeps its state',
  );
  expect(
    result.state,
    isA<_TestStateB>(),
    reason: 'transition result FSM is on the target state',
  );
}

// ============================================================================
// Builder helpers
// ============================================================================

/// Builds a two-state FSM with transitions from A to B and back, starting in
/// [initialState].
ImmutableFSM<_TestEvent, String> _make2StateFSM({
  _TestState initialState = const _TestStateA(),
}) => ImmutableFSM<_TestEvent, String>(initialState: initialState, data: '')
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

/// Builds an FSM in state A with transitions to B and to C.
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

/// Builds an FSM in state C where a transition to D chains on to A.
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

/// Builds the C-D-A FSM and immediately triggers the first transition.
Future<ImmutableFSM<_TestEvent, String>> _makeFSMWithAutostart() async =>
    _makeCDAFSM().tryTransition(event: _TestEvent.goToD);

/// Builds a two-state FSM (A to B) carrying `carried` data.
ImmutableFSM<_TestEvent, String> _makeFlowFSM() =>
    const ImmutableFSM<_TestEvent, String>(
      initialState: _TestStateA(),
      data: 'carried',
    ).addTransition(
      from: const _TestStateA(),
      to: const _TestStateB(),
      event: _TestEvent.goToB,
    );

// ============================================================================
// Fixtures
// ============================================================================

enum _TestEvent { goToB, goToA, goToC, goToD, goToE }

typedef _TestState = FSMState<_TestEvent, String>;

/// Reports the handlers of the states below, in the order they ran.
final List<String> _calls = <String>[];

/// The initial state, which reports its handlers.
class _TestStateA extends _TestState {
  const _TestStateA();

  @override
  Future<void> onEnter(
    String? data, {
    required FSMStateOnEnterResponse<_TestEvent, String> response,
  }) async {
    _calls.add('A.onEnter($data)');
  }

  @override
  Future<void> onExit(
    String? data, {
    required FSMStateOnExitResponse<_TestEvent, String> response,
  }) async {
    _calls.add('A.onExit($data)');
  }
}

/// A target state, which reports its handlers and waits inside [onEnter], to
/// check that asynchronous work in a handler is awaited.
class _TestStateB extends _TestState {
  const _TestStateB();

  @override
  Future<void> onEnter(
    String? data, {
    required FSMStateOnEnterResponse<_TestEvent, String> response,
  }) async {
    await Future<void>.delayed(Duration.zero);
    _calls.add('B.onEnter($data)');
  }

  @override
  Future<void> onExit(
    String? data, {
    required FSMStateOnExitResponse<_TestEvent, String> response,
  }) async {
    _calls.add('B.onExit($data)');
  }
}

/// Stores metadata as it is entered, and reports what it is handed as it is
/// left.
class _TestStateC extends _TestState {
  const _TestStateC();

  @override
  Future<void> onEnter(
    String? data, {
    required FSMStateOnEnterResponse<_TestEvent, String> response,
  }) async {
    _calls.add('C.onEnter($data)');
    response.emitData('State C entered');
  }

  @override
  Future<void> onExit(
    String? data, {
    required FSMStateOnExitResponse<_TestEvent, String> response,
  }) async {
    _calls.add('C.onExit($data)');
  }
}

/// Emits data and an event upon entering, so that the FSM continues the
/// transition chain from itself.
class _TestStateD extends _TestState {
  const _TestStateD();

  @override
  Future<void> onEnter(
    String? data, {
    required FSMStateOnEnterResponse<_TestEvent, String> response,
  }) async {
    _calls.add('D.onEnter($data)');
    response
      ..emitData('State D entered')
      ..emitEvent(_TestEvent.goToA);
  }
}

/// A state with no handlers at all, used for self transitions.
class _TestStateE extends _TestState {
  const _TestStateE();
}

/// Emits data and an event upon exiting.
///
/// [FSMStateOnExitResponse] has no `emitEvent`, but the response the FSM hands
/// to `onExit` is the enter response, so the cast is the only way to emit an
/// event from an exit handler - and the FSM resets the response before
/// [onEnter], which is what drops that event.
class _TestStateF extends _TestState {
  const _TestStateF();

  @override
  Future<void> onExit(
    String? data, {
    required FSMStateOnExitResponse<_TestEvent, String> response,
  }) async {
    _calls.add('F.onExit($data)');
    (response as FSMStateOnEnterResponse<_TestEvent, String>).emitEvent(
      _TestEvent.goToC,
    );
    response.emitData('Left state F');
  }
}

/// Has NO `const` constructor but DOES implement value equality, so two
/// instances of it are the same map key.
class _TestStateG extends _TestState {
  _TestStateG();

  @override
  bool operator ==(Object other) => other is _TestStateG;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Carries nullable [Data] and tries to clear it back to `null`.
class _TestStateH extends FSMState<_TestEvent, String?> {
  const _TestStateH();

  @override
  Future<void> onEnter(
    String? data, {
    required FSMStateOnEnterResponse<_TestEvent, String?> response,
  }) async {
    response.emitData(null);
  }
}
