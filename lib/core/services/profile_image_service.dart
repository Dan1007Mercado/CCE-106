import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ProfileImageService {
  ProfileImageService({
    FirebaseStorage? storage,
    ImagePicker? imagePicker,
  }) : _storage = storage ?? FirebaseStorage.instance,
       _imagePicker = imagePicker ?? ImagePicker();

  final FirebaseStorage _storage;
  final ImagePicker _imagePicker;

  Future<XFile?> pickImage({required ImageSource source}) async {
    try {
      return await _imagePicker.pickImage(
        source: source,
        imageQuality: 86,
        maxWidth: 1600,
      );
    } catch (_) {
      throw Exception('We could not open the selected image source.');
    }
  }

  Future<String> uploadProfileImage({
    required String userId,
    required XFile image,
  }) async {
    try {
      final bytes = await image.readAsBytes();
      final extension = _readExtension(image.name);
      final fileName =
          'profile_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final reference = _storage
          .ref()
          .child('users')
          .child(userId)
          .child('profile')
          .child(fileName);

      await reference.putData(
        bytes,
        SettableMetadata(contentType: _contentTypeFor(extension)),
      );
      return reference.getDownloadURL();
    } on FirebaseException catch (error) {
      throw Exception(
        error.message ?? 'We could not upload your profile image.',
      );
    }
  }

  String _readExtension(String fileName) {
    final pieces = fileName.split('.');
    if (pieces.length < 2) {
      return 'jpg';
    }

    return pieces.last.toLowerCase();
  }

  String _contentTypeFor(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }
}
