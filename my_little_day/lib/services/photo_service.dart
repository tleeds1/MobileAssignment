import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class PhotoException implements Exception {
  PhotoException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Ảnh do gia đình thêm (FR-M2-07, Mục 6.5):
/// lưu trong vùng riêng của ứng dụng, giới hạn định dạng và dung lượng;
/// ảnh không còn được tham chiếu sẽ bị xóa theo chính sách xóa dữ liệu.
class PhotoService {
  static const maxBytes = 5 * 1024 * 1024;
  static const allowedExt = {'.jpg', '.jpeg', '.png', '.webp', '.heic'};

  final ImagePicker _picker = ImagePicker();
  final _uuid = const Uuid();

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(base.path, 'photos'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Trả về đường dẫn ảnh đã sao chép vào vùng riêng, hoặc null nếu hủy.
  Future<String?> pick({bool camera = false}) async {
    final x = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 80,
    );
    if (x == null) return null;
    final ext = p.extension(x.path).toLowerCase();
    if (!allowedExt.contains(ext)) {
      throw PhotoException('Định dạng ảnh chưa được hỗ trợ.');
    }
    final size = await x.length();
    if (size > maxBytes) {
      throw PhotoException('Ảnh quá lớn (tối đa 5 MB).');
    }
    final dest = p.join((await _dir()).path, '${_uuid.v4()}$ext');
    await x.saveTo(dest);
    return dest;
  }

  Future<void> delete(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Xóa ảnh không còn được tham chiếu bởi dữ liệu nào.
  Future<int> purgeUnreferenced(Set<String> referenced) async {
    var removed = 0;
    final d = await _dir();
    await for (final e in d.list()) {
      if (e is File && !referenced.contains(e.path)) {
        await e.delete();
        removed++;
      }
    }
    return removed;
  }

  Future<void> deleteAll() async {
    final d = await _dir();
    if (await d.exists()) await d.delete(recursive: true);
  }
}
