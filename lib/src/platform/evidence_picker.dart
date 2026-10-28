import 'dart:typed_data';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';

import '../core/contracts/input_contract.dart';
import '../core/errors/luliverify_exception.dart';

/// Builds native file-picker filters from a supported backend MIME policy.
///
/// Supplies iOS UTIs plus matching extension/MIME filters for PDF, PNG and JPEG.
/// Use backend-validated MIME values; a filter is selection assistance, not file
/// verification. The picker also inspects file bytes before accepting evidence.
XTypeGroup evidenceTypeGroup(Iterable<String> acceptedMimeTypes) {
  final types = acceptedMimeTypes.toSet();
  return XTypeGroup(
    label: 'Verification document',
    extensions: [
      if (types.contains('application/pdf')) 'pdf',
      if (types.contains('image/png')) 'png',
      if (types.contains('image/jpeg')) ...['jpg', 'jpeg'],
    ],
    uniformTypeIdentifiers: [
      if (types.contains('application/pdf')) 'com.adobe.pdf',
      if (types.contains('image/png')) 'public.png',
      if (types.contains('image/jpeg')) 'public.jpeg',
    ],
    mimeTypes: types.toList(),
  );
}

/// Selected media held in an owned mutable buffer with its detected MIME type.
///
/// A selected file is evidence only, not a verification/liveness outcome. Keep
/// bytes out of logs/analytics and clear the owned buffer after use.
final class LuliVerifyPickedEvidence {
  // Android file_selector may return an unmodifiable platform buffer. Own a
  // mutable copy so post-upload cleanup cannot turn success into a failure.
  /// Copies [bytes] so cleanup cannot mutate a caller’s or platform’s buffer.
  ///
  /// [mimeType] records the detected file type; this constructor does not validate
  /// it. Prefer the validated evidence picker for user-selected media.
  LuliVerifyPickedEvidence(Uint8List bytes, this.mimeType)
    : bytes = Uint8List.fromList(bytes);

  /// Owned mutable evidence bytes; clear after awaited upload/use has finished.
  final Uint8List bytes;

  /// Detected MIME type, such as image/jpeg or application/pdf.
  final String mimeType;
}

/// Native file/camera adapter constrained by the current upload contract.
///
/// Capture is not provider liveness. Production liveness cannot be replaced by
/// a photo; backend-marked test liveness must be opted into explicitly.
class LuliVerifyEvidencePicker {
  final ImagePicker _images = ImagePicker();

  /// Selects or captures one permitted file, returning null on user cancellation.
  ///
  /// [contract] supplies upload enablement, MIME policy and byte limit. [camera]
  /// selects capture rather than a document picker. Optional [capture] replaces
  /// the system camera only when camera is true; it must return a newly created,
  /// operation-owned temporary file or null. That file is deleted best-effort after
  /// reading. User-selected document-provider files are never deleted.
  ///
  /// [testOnlyLiveness] is a development-only opt-in for a test liveness contract;
  /// the session/controller must separately enforce its backend testOnly flag.
  /// Size and file signatures are checked before returning an owned byte buffer.
  /// Throws LuliVerifyException for disabled/unsupported files, permissions/capture
  /// failures, or a provider-required liveness step. Choosing a file proves nothing
  /// about document authenticity or human presence.
  Future<LuliVerifyPickedEvidence?> pick({
    required LuliVerifyInputContract contract,
    bool camera = false,
    bool testOnlyLiveness = false,
    Future<XFile?> Function()? capture,
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
          ? capture != null
                ? await capture()
                : await _images.pickImage(
                    source: ImageSource.camera,
                    requestFullMetadata: false,
                  )
          : await openFile(
              acceptedTypeGroups: [
                evidenceTypeGroup((policy['mimeTypes'] as List).cast<String>()),
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

  /// Retrieves image_picker recovery data after Android activity loss.
  ///
  /// Advanced hosts may call once during startup. Reconfirm the customer, session,
  /// step and role before using recovered media; never attach it automatically.
  /// This does not restore SDK session credentials or accept the capture as passed.
  Future<LostDataResponse> retrieveLostCapture() => _images.retrieveLostData();
}
