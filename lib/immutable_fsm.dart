// Copyright (c) 2024, Iurii Zisin. All rights reserved.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file.
///
/// An immutable
/// [Finite State Machine](https://en.wikipedia.org/wiki/Finite-state_machine).
///
/// It is designed to work well with state management due to immutability -
/// any transition could produces a copy of the FSM state holding new values.
library;

export 'src/immutable_fsm.dart';
