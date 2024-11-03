/// An example of usage of [ImmutableFSM] based on a modified example
/// of a [coin-operated turnstile](https://en.wikipedia.org/wiki/Finite-state_machine#Example:_coin-operated_turnstile).
library;

import 'dart:convert';
import 'dart:io';

import 'package:immutable_fsm/immutable_fsm.dart';
import 'package:meta/meta.dart';

void main() async {
  /// The configured turnstile state machine.
  ImmutableFSM<TurnstileEvent, TurnstileMetadata?> fsm = _initialFSM;

  String? input;
  while (input != 'q') {
    print('\nTurnstile is: ${fsm.state.runtimeType}');
    final Object? error = fsm.data?.error;
    if (error != null) {
      print('Error: $error');
    }
    print('Coin: ${fsm.data?.coinValue}');
    print('''Enter the following:
    - an integer - insert coin of that value
    - p - push the turnstile
    - hit Enter - prints FSM state and configuration  
    - q - Quit
    ''');
    stdout.write('> ');
    input = stdin.readLineSync(encoding: utf8);
    final int? value = int.tryParse(input ?? '');
    try {
      switch (input) {
        case '':
          print('\n${fsm.debugDescription}\n');
        case 'p':
          // Try to push the turnstile
          fsm = await fsm.tryTransition(event: TurnstileEvent.push);
        case 'q':
          break;
        default:
          if (value != null) {
            // Try to put in the coin
            fsm = await fsm.tryTransition(
              event: TurnstileEvent.coinInserted,
              data: TurnstileMetadata(coinValue: value),
            );
            break;
          }

          print('Command not recognized');
      }
    } on Exception catch (exception) {
      print('Unable to process input: $exception');
    }
  }
}

/// Turnstile events that state machine understands.
enum TurnstileEvent {
  /// A coin is put into the turnstile.
  coinInserted,

  /// Unlock the turnstile to allow the passage.
  unlock,

  /// Push the turnstile to walk through.
  push,

  /// Turnstile reported an error.
  error,
}

/// The data associated with turnstile.
///
/// It covers both input and output of the states, keeping the inserted
/// [coinValue] and [error], if any.
@immutable
class TurnstileMetadata {
  const TurnstileMetadata({this.coinValue = 0, this.error});

  final int coinValue;
  final Object? error;

  @override
  String toString() =>
      'TurnstileMetadata{coinValue: $coinValue, error: $error}';
}

/// Locked turnstile - passage is blocked.
class Locked extends FSMState<TurnstileEvent, TurnstileMetadata> {
  const Locked();
}

/// An intermediate state when turnstile processes the coin.
class ReceivingCoin extends FSMState<TurnstileEvent, TurnstileMetadata> {
  const ReceivingCoin();

  /// When a coin is inserted, it verifies that there is a coin and that it's
  /// a coin of the correct value.
  ///
  /// If everything matches, it emits [TurnstileEvent.unlock] and clears the
  /// coin from [TurnstileMetadata] to represent that it went through.
  @override
  Future<void> onEnter(
    TurnstileMetadata? data, {
    required FSMStateOnEnterResponse<TurnstileEvent, TurnstileMetadata>
        response,
  }) async {
    final int? coinValue = data?.coinValue;
    if (coinValue == null) {
      response
        ..emitEvent(TurnstileEvent.error)
        ..emitData(
          const TurnstileMetadata(
            error: WrongCoinException(
              'You have to put in a real coin.',
            ),
          ),
        );
      return;
    }
    if (coinValue == 50) {
      response
        ..emitEvent(TurnstileEvent.unlock)
        ..emitData(const TurnstileMetadata());
      return;
    }
    response
      ..emitEvent(TurnstileEvent.error)
      ..emitData(
        TurnstileMetadata(
          coinValue: coinValue,
          error: WrongCoinException(
            'A coin of 50 is required, but $coinValue was provided - returned.',
          ),
        ),
      );
  }
}

/// Unlocked turnstile, allowing to walk through.
class Unlocked extends FSMState<TurnstileEvent, TurnstileMetadata> {
  const Unlocked();
}

/// An error - representing a state when turnstile refused to accept a coin.
class CoinError extends FSMState<TurnstileEvent, TurnstileMetadata> {
  const CoinError();
}

/// An exception, representing an incorrect coin.
class WrongCoinException implements Exception {
  const WrongCoinException(this.message);

  final String message;

  @override
  String toString() => 'WrongCoinException: $message';
}

/// The configuration of the state machine, which is also it's initial state.
final ImmutableFSM<TurnstileEvent, TurnstileMetadata> _initialFSM =
    const ImmutableFSM<TurnstileEvent, TurnstileMetadata>(
  initialState: Locked(),
  data: TurnstileMetadata(),
)
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
