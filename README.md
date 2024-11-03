# ImmutableFSM

`ImmutableFSM` is a Dart package that implements an immutable Finite State Machine (FSM) that 
supports transient states, integrates smoothly with various state and data management frameworks 
like Riverpod, and is perfect for UI applications.

## Key Features

- **Immutability**: Every action creates a new FSM instance with an updated, immutable state and 
  data, ensuring predictable behavior and reducing side effects.
- **Transient States**: The FSM supports transient states — states that can automatically chain to 
  other states based on internal conditions, making transitions seamless and efficient.
- **Reactive Transitions**: States can provide `onEnter` and `onExit` handlers to perform specific 
  actions when entering or leaving a state, enabling responsive and event-driven behaviors.
- **UI Compatibility**: Due to immutability, `ImmutableFSM` is ideal for UI applications and works 
  seamlessly with data and state and data management frameworks like Riverpod.

## Getting Started

To start using `ImmutableFSM`, add it as a dependency in your `pubspec.yaml` file:

```yaml
dependencies:
  immutable_fsm: ^1.0.0
```

Then, run `flutter pub get` to install the package.

### Importing the Package

In your Dart file, import the package as follows:

```dart
import 'package:immutable_fsm/immutable_fsm.dart';
```

## Usage

Let's consider a simple system we need to model using a state machine - a turnstile. 
In our example, user needs to put a coin into the turnstile in order to pass, and the coin needs to 
be of a specific value.

For our example we will use the two key states - `Locked`, and `Unlocked`. To make our system more
robust and comprehensive, we will add two more states - `ReceivingCoin` - a transient state at which
the coin will be validated, and `CoinError` - the state when turnstile is locked, but error lights
up and if there was a coin it will be returned back to the user.

Now, when we have our states defined, we need to define the events that will trigger the transitions
between the states. We will use the following:

- `coinInserted` - an event that happens when user puts a coin into the turnstile receptacle
- `push` - user pushes through turnstile, trying to walk through it
- `unlock` - an even that unlocks the turnstile, allowing user to pass through
- `error` - an even that happens when an error occurs

### Creating an FSM

To start, define the FSM states and events. States represent the different conditions or modes of 
the system (like `Locked` or `Unlocked`), and events are the triggers that cause transitions between
these states (such as `coinInserted` or `push`). States are created by extending the 
`FSMState<Event, Data>` class, where `Event` is typically an enum listing possible triggers, and 
`Data` represents metadata used during transitions.

```dart
enum TurnstileEvent {
  coinInserted,
  unlock,
  push,
  error,
}

@immutable
class TurnstileMetadata {
  const TurnstileMetadata({this.coinValue = 0, this.error});

  final int coinValue;
  final Object? error;
}

class Locked extends FSMState<TurnstileEvent, TurnstileMetadata> {
  const Locked();
}

class ReceivingCoin extends FSMState<TurnstileEvent, TurnstileMetadata> {
  const ReceivingCoin();

  @override
  Future<void> onEnter(TurnstileMetadata? data, {
    required FSMStateOnEnterResponse<TurnstileEvent, TurnstileMetadata> response,
  }) async {
   // Handle the coin (see example for complete code).
  }
}

class Unlocked extends FSMState<TurnstileEvent, TurnstileMetadata> {
  const Unlocked();
}

class CoinError extends FSMState<TurnstileEvent, TurnstileMetadata> {
  const CoinError();
}
```

### Initializing the FSM

Initialize the FSM by specifying the initial state.

```dart
final fsm = ImmutableFSM<TurnstileEvent, TurnstileMetadata>(initialState: const Locked());
```

### Adding Transitions

Define state transitions using the `addTransition` method, specifying the `from` state, `to` state, 
and `event` that triggers the transition. Each new transition creates a copy of the FSM with the 
updated transition configuration.

```dart
final fsm = ImmutableFSM<TurnstileEvent, TurnstileMetadata>(initialState: const Locked())
  .addTransition(
    from: const Locked(),
    to: const ReceivingCoin(),
    event: TurnstileEvent.coinInserted,
  )
  .addTransition(
    from: const ReceivingCoin(),
    to: const Unlocked(),
    event: TurnstileEvent.unlock,
  )
  .addTransition(
    from: const ReceivingCoin(),
    to: const CoinError(),
    event: TurnstileEvent.error,
  )
  .addTransition(
    from: const Unlocked(),
    to: const Locked(),
    event: TurnstileEvent.push,
  )
  .addTransition(
    from: const CoinError(),
    to: const ReceivingCoin(),
    event: TurnstileEvent.coinInserted,
  );
```

### Transitioning Between States

To perform a transition, use the `tryTransition` method. Since `ImmutableFSM` is immutable, calling 
`tryTransition` doesn’t alter the original FSM but instead returns a new FSM in the updated state. 
This approach maintains immutability, making the FSM predictable and preventing unintended side 
effects.

`tryTransition` takes an event and optional data; if data is provided, it will be passed to the
current state when it exits and to the new state when it enters. If no data is provided, the FSM 
uses the existing metadata associated with the state.

Using an immutable FSM enables integration with state management systems, as each new FSM instance 
can be stored in state providers or containers like `Riverpod`, triggering UI rebuilds on state 
changes.

```dart
fsm = await fsm.tryTransition(
  event: TurnstileEvent.coinInserted, 
  data: const TurnstileMetadata(coinValue: 20),
);
```

### Handling State Changes

The key feature of `ImmutableFSM` is its ability to react to state changes.

Each state can execute code when the FSM enters or exits that state. States can override `onEnter` 
and `onExit` to define behaviors that should occur upon entering or exiting a state.

#### Transient States

One of the distinct features of `ImmutableFSM` is the support for transient states, also known as 
state chaining. Transient states allow a state, upon entering, to automatically transition to 
another state based on internal logic.

These transitions happen internally, making the chaining process transparent to the code executing 
`tryTransition`.

For example, when the turnstile is in the `Locked` state, inserting a coin triggers a transition 
to the `ReceivingCoin` state. Upon entering `ReceivingCoin`, the coin is validated, and the 
turnstile either unlocks (transitioning to `Unlocked`) or throws an error. Here, `ReceivingCoin` is 
a transient state that quickly progresses to the next state based on conditions.

```dart
// FSM state is initially Locked
fsm = await fsm.tryTransition(
  event: TurnstileEvent.coinInserted, 
  data: const TurnstileMetadata(coinValue: 20),
);
// FSM state is now Unlocked, but it went through ReceivingCoin
```

This feature allows developers to create state chains that automate various actions and scenarios 
without burdening the main code with unnecessary state and event handling.

For instance, a turnstile might have states for weighing and measuring a coin before verifying and 
unlocking it. The UI consuming this FSM would only need to track the three main states — locked, 
unlocked, or error — without needing to handle the intermediate states.

This approach encourages **SOLID** and **KISS** principles by making states smaller and easier to 
maintain.

#### State Response

Each state’s `onEnter` and `onExit` methods receive a response object (`FSMStateOnEnterResponse` 
for entering and `FSMStateOnExitResponse` for exiting) that provides methods like `emitData` and 
`emitEvent` to control state progression and handle data updates.

#### Data

The metadata associated with each state acts as a container for both input and output data during 
transitions. When a state processes a transition, it produces a complete immutable metadata object. 
States can copy and modify input data or create entirely new data as output, depending on the 
specific requirements of the transition.

The metadata is global to the FSM and is updated with each state’s new metadata object. If a state 
doesn’t emit new metadata, the FSM retains the current data, allowing multiple states to rely on the
same data without constantly passing it forward.

### Example

Below is an example showing a transient state with `onEnter` using `emitData` and `emitEvent` to 
control state transitions and output data.

```dart
class ReceivingCoin extends FSMState<TurnstileEvent, TurnstileMetadata> {
  const ReceivingCoin();

  @override
  Future<void> onEnter(TurnstileMetadata? data, {
    required FSMStateOnEnterResponse<TurnstileEvent, TurnstileMetadata> response,
  }) async {
    if (data?.coinValue == 20) {
      response
        ..emitData(const TurnstileMetadata())
        ..emitEvent(TurnstileEvent.unlock);
      return;
    }
    response.emitEvent(TurnstileEvent.error);
  }
}
```

In this example, the `ReceivingCoin` state verifies the coin's value. If the value matches, it emits a new metadata object and triggers the `unlock` event. Otherwise, it emits an error event.

