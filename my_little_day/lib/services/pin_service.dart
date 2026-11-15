import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Kho bí mật trừu tượng để có thể kiểm thử không cần nền tảng.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformSecretStore implements SecretStore {
  final _s = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

class MemorySecretStore implements SecretStore {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> delete(String key) async => data.remove(key);
}

enum PinCheck { ok, wrong, lockedOut, notSet }

class PinResult {
  const PinResult(this.check, {this.remainingAttempts, this.lockedUntil});
  final PinCheck check;
  final int? remainingAttempts;
  final DateTime? lockedUntil;
}

/// Xác minh người chăm sóc bằng PIN (UI-07).
///
/// - Chỉ lưu hash SHA-256 có salt + nhiều vòng lặp trong secure storage.
/// - Sai [maxAttempts] lần → tạm khóa [lockout], tăng dần nếu tiếp tục sai.
/// - Khôi phục quyền truy cập: trả lời câu hỏi khôi phục do người chăm sóc
///   tự đặt khi tạo PIN (không gửi đi đâu).
class PinService {
  PinService(this._store, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final SecretStore _store;
  final DateTime Function() _now;

  static const maxAttempts = 5;
  static const lockout = Duration(seconds: 30);
  static const _iterations = 10000;

  static const _kHash = 'pin.hash';
  static const _kSalt = 'pin.salt';
  static const _kFails = 'pin.fails';
  static const _kLockUntil = 'pin.lockUntil';
  static const _kLockCount = 'pin.lockCount';
  static const _kRecoveryQ = 'pin.recoveryQ';
  static const _kRecoveryHash = 'pin.recoveryHash';

  Future<bool> hasPin() async => (await _store.read(_kHash)) != null;

  static bool isValidPin(String pin) => RegExp(r'^\d{4,6}$').hasMatch(pin);

  Future<void> setPin(String pin,
      {String? recoveryQuestion, String? recoveryAnswer}) async {
    if (!isValidPin(pin)) {
      throw ArgumentError('PIN phải gồm 4–6 chữ số');
    }
    final salt = _randomSalt();
    await _store.write(_kSalt, salt);
    await _store.write(_kHash, _hash(pin, salt));
    await _resetFailures();
    if (recoveryQuestion != null &&
        recoveryAnswer != null &&
        recoveryAnswer.trim().isNotEmpty) {
      await _store.write(_kRecoveryQ, recoveryQuestion);
      await _store.write(
          _kRecoveryHash, _hash(_normalize(recoveryAnswer), salt));
    }
  }

  Future<DateTime?> lockedUntil() async {
    final v = await _store.read(_kLockUntil);
    if (v == null) return null;
    final until = DateTime.tryParse(v);
    if (until == null || !until.isAfter(_now())) return null;
    return until;
  }

  Future<PinResult> verify(String pin) async {
    final hash = await _store.read(_kHash);
    final salt = await _store.read(_kSalt);
    if (hash == null || salt == null) return const PinResult(PinCheck.notSet);

    final until = await lockedUntil();
    if (until != null) {
      return PinResult(PinCheck.lockedOut, lockedUntil: until);
    }
    if (_hash(pin, salt) == hash) {
      await _resetFailures();
      return const PinResult(PinCheck.ok);
    }
    final fails = int.parse(await _store.read(_kFails) ?? '0') + 1;
    if (fails >= maxAttempts) {
      final lockCount = int.parse(await _store.read(_kLockCount) ?? '0') + 1;
      final wait = lockout * lockCount; // 30s, 60s, 90s …
      final lockUntil = _now().add(wait);
      await _store.write(_kLockUntil, lockUntil.toIso8601String());
      await _store.write(_kLockCount, '$lockCount');
      await _store.write(_kFails, '0');
      return PinResult(PinCheck.lockedOut, lockedUntil: lockUntil);
    }
    await _store.write(_kFails, '$fails');
    return PinResult(PinCheck.wrong, remainingAttempts: maxAttempts - fails);
  }

  Future<String?> recoveryQuestion() => _store.read(_kRecoveryQ);

  Future<bool> verifyRecovery(String answer) async {
    final h = await _store.read(_kRecoveryHash);
    final salt = await _store.read(_kSalt);
    if (h == null || salt == null) return false;
    if (await lockedUntil() != null) return false;
    final ok = _hash(_normalize(answer), salt) == h;
    if (!ok) {
      // Câu trả lời sai cũng tính vào số lần thử.
      await verify('__invalid__');
    }
    return ok;
  }

  Future<void> clearAll() async {
    for (final k in [
      _kHash,
      _kSalt,
      _kFails,
      _kLockUntil,
      _kLockCount,
      _kRecoveryQ,
      _kRecoveryHash,
    ]) {
      await _store.delete(k);
    }
  }

  Future<void> _resetFailures() async {
    await _store.delete(_kFails);
    await _store.delete(_kLockUntil);
    await _store.delete(_kLockCount);
  }

  static String _normalize(String s) => s.trim().toLowerCase();

  static String _randomSalt() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  static String _hash(String secret, String salt) {
    var bytes = utf8.encode('$salt:$secret');
    for (var i = 0; i < _iterations; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64Url.encode(bytes);
  }
}
