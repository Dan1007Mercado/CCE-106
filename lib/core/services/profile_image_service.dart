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

  Future<XFile?> pickImage() {
    return _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
      maxWidth: 1600,
    );
  }

  Future<String> uploadProfileImage({
    required String userId,
    required XFile image,
  }) async {
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

    await reference.putData(bytes);
    return reference.getDownloadURL();
  }

  String _readExtension(String fileName) {
    final pieces = fileName.split('.');
    if (pieces.length < 2) {
      return 'jpg';
    }

    return pieces.last.toLowerCase();
  }
}
