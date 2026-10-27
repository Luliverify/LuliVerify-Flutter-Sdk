import 'dart:typed_data';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';

import '../core/contracts/input_contract.dart';
import '../core/errors/luliverify_exception.dart';

final class LuliVerifyPickedEvidence {
  const LuliVerifyPickedEvidence(this.bytes, this.mimeType);
  final Uint8List bytes;
  final String mimeType;
}

/// Native image capture is NOT liveness. Callers must not use it as such.
class LuliVerifyEvidencePicker {
  final ImagePicker _images = ImagePicker();
  Future<LuliVerifyPickedEvidence?> pick({
    required LuliVerifyInputContract contract,
    bool camera = false,
    bool testOnlyLiveness = false,
  }) async {
    if (contract.toolType == 'liveness' && !testOnlyLiveness) {
      throw const LuliVerifyException(
        'provider_required',
        'A provider-supported liveness capture is required.',
      );
    }
    final policy = contract.uploads;
    if (policy['enabled'] != true) {
      throw const LuliVerifyException(
        'upload_disabled',
        'This step does not accept uploads.',
      );
    }
    XFile? ownedCameraFile;
    try {
      final XFile? file = camera
          ? await _images.pickImage(
              source: ImageSource.camera,
              requestFullMetadata: false,
            )
          : await openFile(
              acceptedTypeGroups: [
                XTypeGroup(
                  label: 'Verification document',
                  extensions: [
                    if ((policy['mimeTypes'] as List).contains(
                      'application/pdf',
                    ))
                      'pdf',
                    'png',
                    'jpg',
                    'jpeg',
                  ],
                ),
              ],
            );
      if (file == null) return null;
      if (camera) ownedCameraFile = file;
      if (await file.length() > (policy['maxBytes'] as int)) {
        throw const LuliVerifyException(
          'file_too_large',
          'The selected file exceeds the upload limit.',
        );
      }
      final bytes = await file.readAsBytes();
      final mime =
          bytes.length >= 4 &&
              bytes[0] == 0x89 &&
              bytes[1] == 0x50 &&
              bytes[2] == 0x4e &&
              bytes[3] == 0x47
          ? 'image/png'
          : bytes.length >= 3 &&
                bytes[0] == 0xff &&
                bytes[1] == 0xd8 &&
                bytes[2] == 0xff
          ? 'image/jpeg'
          : bytes.length >= 5 && String.fromCharCodes(bytes.take(5)) == '%PDF-'
          ? 'application/pdf'
          : null;
      if (mime == null || !(policy['mimeTypes'] as List).contains(mime)) {
        throw const LuliVerifyException(
          'unsupported_file',
          'Select a supported PDF, PNG or JPEG file.',
        );
      }
      return LuliVerifyPickedEvidence(bytes, mime);
    } on LuliVerifyException {
      rethrow;
    } catch (_) {
      throw const LuliVerifyException(
        'capture_unavailable',
        'File capture is unavailable. Check permissions or select a file instead.',
      );
    } finally {
      // Only the newly created camera cache file belongs to this operation.
      // Never delete a document chosen from the customer's file provider.
      if (ownedCameraFile != null) {
        try {
          await File(ownedCameraFile.path).delete();
        } catch (_) {
          /* OS cache cleanup may be deferred. */
        }
      }
    }
  }

  /// Call once on Android startup. Recovered media must be re-confirmed against
  /// the current backend step; never attach it automatically to another session.
  Future<LostDataResponse> retrieveLostCapture() => _images.retrieveLostData();
}
