import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class JobPhotoService {
  JobPhotoService({FirebaseStorage? storage, ImagePicker? imagePicker})
    : _storage = storage ?? FirebaseStorage.instance,
      _imagePicker = imagePicker ?? ImagePicker();

  final FirebaseStorage _storage;
  final ImagePicker _imagePicker;

  Future<XFile?> pickJobPhoto() async {
    try {
      return await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 86,
        maxWidth: 1600,
      );
    } catch (_) {
      throw Exception('We could not open your gallery.');
    }
  }

  Future<String> uploadJobPhoto({
    required String userId,
    required XFile image,
  }) async {
    try {
      final bytes = await image.readAsBytes();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final reference = _storage
          .ref()
          .child('job_photos')
          .child(userId)
          .child('$timestamp.jpg');

      await reference.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return reference.getDownloadURL();
    } on FirebaseException catch (error) {
      throw Exception(error.message ?? 'We could not upload the job photo.');
    }
  }
}
