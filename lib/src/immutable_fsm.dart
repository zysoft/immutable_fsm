// Copyright (c) 2024, Iurii Zisin. All rights reserved.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:meta/meta.dart';

/// An immutable
/// [Finite State Machine](https://en.wikipedia.org/wiki/Finite-state_machine).
///
/// It is designed to work well with state management due to immutability -
/// any transition produces a copy of the FSM state holding new values.
///
/// States have the ability to modify carried [data], which happens at the time
/// if the transition, when the states also get a chance to perform operations.
@immutable
final class ImmutableFSM<Event, Data> {
  /// Creates a new state machine that is set to its [initialState], and holds
  /// the default [data].
  ///
  /// [initialState] **is not receiving** [FSMState.onEnter] call, but it will
  /// receive [FSMState.onExit] upon transition.
  const ImmutableFSM({
    required FSMState<Event, Data> initialState,
    Data? data,
  }) : this._(
          state: initialState,
          data: data,
          transitions: const _TransitionMap<Never, Never>.empty(),
        );

  /// Internal constructor that allows re-creating the complete state
  /// of the FSM.
  const ImmutableFSM._({
    required this.state,
    required _TransitionMap<Event, Data> transitions,
    this.data,
  }) : _transitions = transitions;

  /// Copies self with only specified data replaced.
  ImmutableFSM<Event, Data> _copyWith({
    FSMState<Event, Data>? state,
    Data? data,
    _TransitionMap<Event, Data>? transitions,
  }) =>
      ImmutableFSM<Event, Data>._(
        state: state ?? this.state,
        data: data ?? this.data,
        transitions: transitions ?? _transitions,
      );

  /// Current state.
  final FSMState<Event, Data> state;

  /// The transitions map.
  final _TransitionMap<Event, Data> _transitions;

  /// Current metadata.
  ///
  /// This is controlled by the states and external code.
  /// State machine does not modify this object itself, but it respects the
  /// modifications made by the states during the state transition.
  final Data? data;

  /// Registers a new transition between [from] and [to] states on
  /// a given [event].
  ///
  /// For the state machine to function at least one transition has to be
  /// defined.
  ImmutableFSM<Event, Data> addTransition({
    required FSMState<Event, Data> from,
    required FSMState<Event, Data> to,
    required Event event,
  }) {
    IMap<FSMState<Event, Data>, _Transition<Event, Data>> newTransitions =
        _TransitionMap<Event, Data>(
      const <FSMState<Never, Never>, _Transition<Never, Never>>{},
    );

    if (_transitions.isNotEmpty) {
      newTransitions = newTransitions.addAll(_transitions);
    }
    _Transition<Event, Data> transition =
        newTransitions[from] ?? _Transition<Event, Data>();
    transition = transition.add(event, to);

    newTransitions = newTransitions.add(from, transition);

    return _copyWith(
      transitions: newTransitions,
    );
  }

  /// Attempts to transition the state machine to a new state, which is
  /// triggered by the [event], passing [data] over to the affected states.
  ///
  /// The current state will receive [FSMState.onExit] call,
  /// which could modify the [data], which then gets passed to the new
  /// state, the machine is transitioning into, by calling [FSMState.onEnter],
  /// which also can modify the [data], and the resulting [data] will be
  /// stored in the [ImmutableFSM.data].
  ///
  /// Throws [FSMException] if there's no transition defined for the [event].
  Future<ImmutableFSM<Event, Data>> tryTransition({
    required Event event,
    Data? data,
  }) async {
    final _Transition<Event, Data>? transition = _transitions[state];
    final FSMState<Event, Data>? toState = transition?[event];
    if (transition == null || toState == null) {
      throw FSMException('No transition from $state on $event');
    }

    final FSMStateOnEnterResponse<Event, Data> response =
        FSMStateOnEnterResponse<Event, Data>._();

    Data? newData = data;
    await state.onExit(newData, response: response);
    newData = response._data ?? newData;
    response._reset();
    await toState.onEnter(newData, response: response);
    newData = response._data ?? newData;
    final ImmutableFSM<Event, Data> newSelf = _copyWith(
      state: toState,
      data: newData,
    );
    final Event? triggeredEvent = response._event;
    if (triggeredEvent != null) {
      return newSelf.tryTransition(event: triggeredEvent, data: newSelf.data);
    }
    return newSelf;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImmutableFSM &&
          runtimeType == other.runtimeType &&
          state == other.state &&
          data == other.data &&
          const DeepCollectionEquality()
              .equals(_transitions, other._transitions);

  @override
  int get hashCode => Object.hash(
        state,
        _transitions,
        data,
      );

  //coverage:ignore-start
  @override
  String toString() => 'ImmutableFSM(state: $state, data: $data)';
  //coverage:ignore-end

  /// Produces debug description of the FSM, containing it's current state,
  /// data, and configuration.
  ///
  /// Will use standard `toString` when outputting the [data] and `runtimeType`
  /// of the [state].
  //coverage:ignore-start
  String get debugDescription {
    final StringBuffer buf = StringBuffer()
      ..writeln('ImmutableFSM')
      ..writeln('    state: ${state.runtimeType}')
      ..writeln('    data: $data')
      ..writeln('Transitions:');
    for (final FSMState<Event, Data> transition in _transitions.keys) {
      buf.writeln('${''.padLeft(3)} ${transition.runtimeType}:');
      for (final Event event in _transitions[transition]?.keys ?? <Event>[]) {
        buf.writeln(
          '${''.padLeft(7)} on $event '
          '-> ${_transitions[transition]?[event]?.runtimeType}',
        );
      }
    }

    return buf.toString();
  }
  //coverage:ignore-end
}

/// An [ImmutableFSM]'s state.
///
/// Defines [onEnter] and [onExit] handlers that descendants can
/// override in order to provide their own logic.
///
/// By default [onEnter] and [onExit] do nothing.
abstract class FSMState<Event, Data> {
  const FSMState();

  /// Gets executed when [ImmutableFSM] transitions into this state.
  @visibleForOverriding
  Future<void> onEnter(
    Data? data, {
    required FSMStateOnEnterResponse<Event, Data> response,
  }) async {}

  /// Gets executed when [ImmutableFSM] transitions out of this state.
  @visibleForOverriding
  Future<void> onExit(
    Data? data, {
    required FSMStateOnExitResponse<Event, Data> response,
  }) async {}
}

/// A transition type - just an alias for readability.
typedef _Transition<Event, Data> = IMap<Event, FSMState<Event, Data>>;

/// A type alias for the hashmap holding the states and transitions.
typedef _TransitionMap<Event, Data>
    = IMap<FSMState<Event, Data>, _Transition<Event, Data>>;

/// A handler that is given to any [FSMState] to provide a response.
///
/// The data passed to [emitData] will be included in the FSM state update.
///
/// If an event is emitted via [emitEvent], FSM will call
/// [ImmutableFSM.tryTransition] again to continue the process
/// **withing the same state update cycle**, i.e. there will be no chance for
/// state monitoring entities to catch the intermediate state changes.
final class FSMStateOnEnterResponse<Event, Data>
    extends FSMStateOnExitResponse<Event, Data> {
  FSMStateOnEnterResponse._() : super._();

  /// Emitted event.
  Event? _event;

  /// Emit an [event] to advance FSM to the next state.
  //ignore: use_setters_to_change_properties
  void emitEvent(Event event) => this._event = event;

  /// Clears the handler.
  @override
  void _reset() {
    _event = null;
    super._reset();
  }
}

/// A handler that is provided to any [FSMState] to provide a response.
///
/// The data passed to [emitData] will be included in the FSM state update.
final class FSMStateOnExitResponse<Event, Data> {
  FSMStateOnExitResponse._();

  /// Emitted data.
  Data? _data;

  /// Emit an updated [data] to export metadata out of the state.
  //ignore: use_setters_to_change_properties
  void emitData(Data data) => this._data = data;

  /// Clears the handler.
  void _reset() {
    _data = null;
  }
}

/// State machine exception.
class FSMException implements Exception {
  /// Creates new exception with the given [message].
  const FSMException(this.message);

  /// Exception message.
  final String message;

  //coverage:ignore-start
  @override
  String toString() => 'FSMException: $message';
  //coverage:ignore-end
}
