import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// What a single permission request actually answered.
///
/// [denied] and [permanentlyDenied] are kept distinct on purpose: the first is
/// recoverable by asking again, the second is only recoverable in the OS's own
/// settings, and telling a user to "allow it next time" when the OS will never
/// ask again is the worst of both.
enum PermissionOutcome {
  granted,

  /// Refused this time. The OS will still show a prompt on a later request.
  denied,

  /// Refused for good. Only the OS settings screen can change it now.
  permanentlyDenied,

  /// No such permission on this platform — desktop, web, or an OS version
  /// that does not use it. Never surfaced to the user as a refusal.
  unavailable;

  bool get isGranted => this == PermissionOutcome.granted;

  /// True only when opening the OS settings page would actually help.
  bool get needsSettings => this == PermissionOutcome.permanentlyDenied;
}

/// Which OS permissions were granted after [AppPermissions.requestAll].
class PermissionResults {
  const PermissionResults({
    required this.camera,
    required this.photos,
    required this.location,
    required this.notifications,
  });

  final bool camera;
  final bool photos;
  final bool location;
  final bool notifications;

  /// The two this screen actually needs to do its job.
  bool get canPickImage => camera || photos;
}

/// Requests the app's OS permissions.
///
/// **Requested up front, on Account Setup open, by explicit decision.**
///
/// Both Apple and Google recommend requesting a permission at the moment it
/// is used, with visible context, and asking for permissions before their
/// feature is opened (the map and notifications here) is a known
/// App Store review-rejection risk and lowers grant rates for later prompts.
/// That trade-off was raised and the up-front approach was chosen anyway.
///
/// If review pushes back, the fix is small: stop calling [requestAll] on
/// screen open and call [requestForImageSource] at the point the user taps
/// upload instead — that method already exists for exactly that purpose.
class AppPermissions {
  AppPermissions._();

  /// Asks for camera, photos, location and notifications in sequence.
  ///
  /// Never throws — a denied or unavailable permission comes back as false so
  /// the screen can carry on rather than blocking the user.
  /// Unchanged in timing and in the number of prompts it shows: still one
  /// sweep on Account Setup open. It reports only granted/not, because a
  /// recovery prompt belongs at the point a permission is actually needed —
  /// four "open settings" nudges on screen open would be worse than useless.
  static Future<PermissionResults> requestAll() async {
    final camera = await _request(Permission.camera);
    final photos = await _requestPhotos();
    final location = await _request(Permission.locationWhenInUse);
    final notifications = await _request(Permission.notification);

    return PermissionResults(
      camera: camera.isGranted,
      photos: photos.isGranted,
      location: location.isGranted,
      notifications: notifications.isGranted,
    );
  }

  /// Requests only what a specific pick needs — the in-context alternative.
  static Future<PermissionOutcome> requestForImageSource({
    required bool fromCamera,
  }) => fromCamera ? _request(Permission.camera) : _requestPhotos();

  /// Requests notification permission when the user enables it in Settings.
  /// Disabling the app preference cannot revoke an OS permission.
  static Future<PermissionOutcome> requestNotifications() =>
      _request(Permission.notification);

  /// Opens the OS settings page for this app.
  ///
  /// Only ever called after the user has explicitly asked for it — nothing
  /// here opens settings on its own.
  static Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (error) {
      debugPrint('Could not open app settings: $error');
      return false;
    }
  }

  /// Android's storage/photos permission changed shape across versions, and
  /// `Permission.photos` maps to the modern one; older devices report it as
  /// permanently denied, so fall back to `storage` there.
  static Future<PermissionOutcome> _requestPhotos() async {
    final photos = await _request(Permission.photos);
    if (photos.isGranted) return photos;
    if (defaultTargetPlatform != TargetPlatform.android) return photos;

    // Same two requests as before — no extra prompt is introduced here.
    final storage = await _request(Permission.storage);
    if (storage.isGranted) return storage;

    // Prefer the answer the user can act on. On a modern Android `storage` is
    // not the permission in use and reports a plain denial, which would hide
    // a real permanent denial of `photos` behind it.
    if (photos.needsSettings || storage.needsSettings) {
      return PermissionOutcome.permanentlyDenied;
    }
    return storage == PermissionOutcome.unavailable ? photos : storage;
  }

  /// Requests [permission] and reports what the OS answered.
  ///
  /// The outcome is read from the **request result**, never from a prior
  /// `status` check: since permission_handler 13 the Android status cannot
  /// distinguish "denied" from "permanently denied", and only the result of
  /// `request()` can (see `SECURITY.md` 8).
  static Future<PermissionOutcome> _request(Permission permission) async {
    try {
      final status = await permission.request();
      if (status.isGranted || status.isLimited) {
        return PermissionOutcome.granted;
      }
      if (status.isPermanentlyDenied || status.isRestricted) {
        // `restricted` is iOS parental controls: the user cannot grant it here
        // either, and settings is still the only place it can change.
        return PermissionOutcome.permanentlyDenied;
      }
      return PermissionOutcome.denied;
    } catch (e) {
      // Unsupported on this platform (e.g. running the app on desktop/web).
      debugPrint('Permission ${permission.value} unavailable: $e');
      return PermissionOutcome.unavailable;
    }
  }
}
