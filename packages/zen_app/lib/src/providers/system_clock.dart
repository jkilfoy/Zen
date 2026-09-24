/// §11.11. The one place `DateTime.now()` is allowed.
library;

import 'package:zen_domain/zen_domain.dart';

/// §11.11, §3. The platform clock, truncated to whole milliseconds.
///
/// "A ban on `DateTime.now()` outside `zen_app`" makes this the only reading of
/// the wall clock in the application, and §3 requires the truncation to happen
/// "where instants enter the system", which is here.
final class SystemClock implements Clock {
  /// Creates a clock reporting [zoneId], the device's IANA zone.
  const SystemClock({required this.zoneId});

  /// EOD-5. The device's IANA zone, e.g. `America/St_Johns`. Resolved once in
  /// `main.dart`, because a zone change mid-session is not something the MVP
  /// reacts to.
  final String zoneId;

  @override
  DateTime nowUtc() => truncateToMilliseconds(DateTime.now().toUtc());

  @override
  String localZoneId() => zoneId;
}
