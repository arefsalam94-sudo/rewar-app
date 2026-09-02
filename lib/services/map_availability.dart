import 'package:flutter/foundation.dart';

/// Whether an embedded Google Map can be created on this build.
///
/// Android and iOS use their native project configuration. Web is disabled
/// until a real Maps JavaScript API key is added to `web/index.html`; creating
/// a map with the placeholder key leaves rejected promises in the browser and
/// can pause development sessions.
bool get googleMapsAvailable => !kIsWeb;
