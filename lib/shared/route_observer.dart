import 'package:flutter/widgets.dart';

/// The single app-wide route observer, registered in `MaterialApp.router`.
///
/// Widgets mix in `RouteAware`, subscribe to this observer, and pause
/// themselves in `didPushNext` / resume in `didPopNext` so playback does not
/// keep running while its route is covered by another one.
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
