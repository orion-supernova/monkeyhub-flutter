import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Host side of `integration_test/capture_flow_test.dart`: writes each
/// screenshot the device takes into $CAPTURE_SHOTS (or ./capture_shots).
Future<void> main() => integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        final dir = Platform.environment['CAPTURE_SHOTS'] ?? 'capture_shots';
        final f = File('$dir/$name.png');
        await f.parent.create(recursive: true);
        await f.writeAsBytes(bytes);
        return true;
      },
    );
