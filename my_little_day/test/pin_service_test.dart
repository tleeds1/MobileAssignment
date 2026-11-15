import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_day/services/pin_service.dart';

void main() {
  late MemorySecretStore store;
  late DateTime now;
  late PinService pin;

  setUp(() {
    store = MemorySecretStore();
    now = DateTime(2026, 11, 16, 9);
    pin = PinService(store, clock: () => now);
  });

  test('chưa có PIN → notSet', () async {
    expect(await pin.hasPin(), isFalse);
    expect((await pin.verify('1234')).check, PinCheck.notSet);
  });

  test('PIN phải 4–6 chữ số', () async {
    expect(() => pin.setPin('12'), throwsArgumentError);
    expect(() => pin.setPin('abcd'), throwsArgumentError);
  });

  test('chỉ lưu hash, không lưu PIN dạng rõ', () async {
    await pin.setPin('2468');
    expect(store.data.values.any((v) => v.contains('2468')), isFalse);
  });

  test('đúng PIN → ok; sai → wrong với số lần còn lại', () async {
    await pin.setPin('2468');
    expect((await pin.verify('2468')).check, PinCheck.ok);
    final r = await pin.verify('0000');
    expect(r.check, PinCheck.wrong);
    expect(r.remainingAttempts, PinService.maxAttempts - 1);
  });

  test('sai nhiều lần → tạm khóa, kể cả PIN đúng; hết hạn thì mở lại', () async {
    await pin.setPin('2468');
    PinResult r = const PinResult(PinCheck.wrong);
    for (var i = 0; i < PinService.maxAttempts; i++) {
      r = await pin.verify('0000');
    }
    expect(r.check, PinCheck.lockedOut);
    expect((await pin.verify('2468')).check, PinCheck.lockedOut);

    now = now.add(PinService.lockout + const Duration(seconds: 1));
    expect((await pin.verify('2468')).check, PinCheck.ok);
  });

  test('khôi phục bằng câu hỏi bí mật (không phân biệt hoa thường)', () async {
    await pin.setPin('2468',
        recoveryQuestion: 'Thú cưng?', recoveryAnswer: 'Miu');
    expect(await pin.recoveryQuestion(), 'Thú cưng?');
    expect(await pin.verifyRecovery('  miu '), isTrue);
    expect(await pin.verifyRecovery('gâu'), isFalse);
  });
}
