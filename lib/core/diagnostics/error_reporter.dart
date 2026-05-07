import 'package:flutter/foundation.dart';

/// Single sink for uncaught errors. The Flutter framework hooks
/// (FlutterError.onError, PlatformDispatcher.instance.onError) and the
/// runZonedGuarded handler in `bootstrap()` all funnel through here.
///
/// Production builds attach a swappable [ErrorSink] — Sentry,
/// Crashlytics, or our own backend can be plugged in by calling
/// [ErrorReporter.attach] before [install]. In debug we just rethrow to
/// the console so stack traces aren't swallowed.
typedef ErrorSink = void Function(Object error, StackTrace stack);

class ErrorReporter {
  ErrorReporter._();

  static final ErrorReporter instance = ErrorReporter._();

  ErrorSink? _sink;
  bool _release = false;

  /// Wires Flutter's framework + platform error handlers to this
  /// reporter. Safe to call from `main()` exactly once. After [install]
  /// every uncaught error in the widget tree, in async work scheduled
  /// from runZonedGuarded, and from the platform layer reaches [report].
  static void install({required bool release}) {
    instance._release = release;

    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      instance.report(details.exception, details.stack ?? StackTrace.current,
          context: details.context?.toDescription());
      // Keep Flutter's own dump so the console still shows the error
      // during development. Sinks add to this, they don't replace it.
      previous?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      instance.report(error, stack);
      return true;
    };
  }

  /// Replace the active sink. Call before [install] to start fresh, or
  /// any time after to swap implementations (e.g. lazily after Sentry
  /// finishes its async init).
  static void attach(ErrorSink sink) {
    instance._sink = sink;
  }

  void report(Object error, StackTrace stack, {String? context}) {
    final sink = _sink;
    if (sink != null) {
      try {
        sink(error, stack);
      } catch (_) {
        // A broken sink must never bring the app down.
      }
    }
    if (!_release) {
      // Surface in console so devs see the error immediately.
      // ignore: avoid_print
      debugPrint('Uncaught error${context == null ? '' : ' ($context)'}: '
          '$error\n$stack');
    }
  }
}
