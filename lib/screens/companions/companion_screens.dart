/// Which screen a companion opens. One switch, so the settings hub, the
/// storage screen and the download banner cannot send the same companion to
/// different places.
library;

import 'package:flutter/widgets.dart';

import '../../companions/companion.dart';
import 'bartleby_screen.dart';
import 'marlowe_screen.dart';
import 'sebastian_screen.dart';

Widget companionScreen(Companion companion) => switch (companion) {
      Companion.sebastian => const SebastianScreen(),
      Companion.marlowe => const MarloweScreen(),
      Companion.bartleby => const BartlebyScreen(),
    };
