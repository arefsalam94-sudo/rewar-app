import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'firebase_bootstrap.dart';

/// Finishes the profile after registration: the display name and the optional
/// profile picture.
///
/// The picture goes to Firebase Storage under `profile_images/{uid}/`, which
/// is the only path the user is allowed to write (`storage.rules`,
/// `SECURITY.md` 2). Firestore stores just the resulting download URL.
class ProfileSetupService {
  ProfileSetupService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _authOverride = auth,
       _firestoreOverride = firestore,
       _storageOverride = storage;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseStorage? _storageOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;

  /// Largest profile picture accepted, matching the ceiling enforced in
  /// `storage.rules`. Checked here too so the user gets a fast, clear error
  /// instead of a failed upload.
  static const int maxImageBytes = 5 * 1024 * 1024; // 5 MB

  /// Saves [displayName] and, if given, uploads [imageFile].
  ///
  /// Returns the stored image URL, or null when no picture was chosen —
  /// the picture is optional, only the name is required.
  Future<String?> completeSetup({
    required String displayName,
    File? imageFile,
  }) async {
    if (!FirebaseBootstrap.isReady) {
      throw StateError('Firebase is not configured — see FIREBASE_SETUP.md');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user to finish setting up.');
    }

    String? imageUrl;
    if (imageFile != null) {
      imageUrl = await _uploadImage(uid: user.uid, file: imageFile);
    }

    await user.updateDisplayName(displayName);

    // `name` and `profileImageUrl` are both on the client-writable allow-list
    // in firestore.rules; nothing privileged is touched here.
    await _firestore.collection('users').doc(user.uid).set({
      'name': displayName,
      'profileImageUrl': ?imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return imageUrl;
  }

  /// Replaces just the profile photo, for the Home screen's side drawer —
  /// unlike [completeSetup], the display name is left untouched.
  Future<String> updateProfilePhoto(File imageFile) async {
    if (!FirebaseBootstrap.isReady) {
      throw StateError('Firebase is not configured — see FIREBASE_SETUP.md');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user to update a photo for.');
    }

    final imageUrl = await _uploadImage(uid: user.uid, file: imageFile);
    // `profileImageUrl` is on the client-writable allow-list in
    // firestore.rules; `name` is deliberately absent from this write.
    await _firestore.collection('users').doc(user.uid).set({
      'profileImageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return imageUrl;
  }

  Future<String> _uploadImage({required String uid, required File file}) async {
    final length = await file.length();
    if (length > maxImageBytes) {
      throw const ImageTooLargeException();
    }

    // Fixed filename per user, so re-uploading replaces the old picture
    // rather than leaving orphaned files behind in Storage.
    final ref = _storage.ref().child('profile_images/$uid/avatar.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}

class ImageTooLargeException implements Exception {
  const ImageTooLargeException();
}
