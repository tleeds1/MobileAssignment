import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../services/pin_service.dart';
import '../../state/caregiver_session.dart';
import 'caregiver_guard.dart';
import 'caregiver_home.dart';

enum _Mode { loading, create, confirm, verify, recover }

/// UI-07 – Xác minh người chăm sóc (Hình 9).
/// Trạng thái: thành công, sai PIN, tạm khóa (hết thời gian), khôi phục.
class PinScreen extends StatefulWidget {
  const PinScreen({super.key, this.afterUnlock});

  /// Màn hình mở sau khi xác minh (mặc định: bảng điều khiển).
  final Widget? afterUnlock;

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  _Mode _mode = _Mode.loading;
  String _pin = '';
  String _firstPin = '';
  String? _error;
  DateTime? _lockedUntil;
  Timer? _lockTimer;
  String? _recoveryQuestion;
  final _recoveryQ = TextEditingController();
  final _recoveryA = TextEditingController();

  PinService get _svc => context.read<PinService>();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final has = await _svc.hasPin();
    final locked = await _svc.lockedUntil();
    final q = await _svc.recoveryQuestion();
    if (!mounted) return;
    setState(() {
      _mode = has ? _Mode.verify : _Mode.create;
      _recoveryQuestion = q;
      _setLock(locked);
    });
  }

  void _setLock(DateTime? until) {
    _lockedUntil = until;
    _lockTimer?.cancel();
    if (until != null) {
      _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (DateTime.now().isAfter(until)) {
          _lockTimer?.cancel();
          setState(() {
            _lockedUntil = null;
            _error = null;
          });
        } else {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _recoveryQ.dispose();
    _recoveryA.dispose();
    super.dispose();
  }

  void _unlock() {
    context.read<CaregiverSession>().unlock();
    Navigator.of(context).pushReplacement(
      caregiverRoute(widget.afterUnlock ?? const CaregiverHome()),
    );
  }

  Future<void> _onDigit(String d) async {
    if (_lockedUntil != null || _pin.length >= 6) return;
    setState(() {
      _pin += d;
      _error = null;
    });
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    switch (_mode) {
      case _Mode.create:
        if (!PinService.isValidPin(_pin)) {
          setState(() => _error = 'PIN cần 4–6 chữ số.');
          return;
        }
        setState(() {
          _firstPin = _pin;
          _pin = '';
          _mode = _Mode.confirm;
        });
        break;
      case _Mode.confirm:
        if (_pin != _firstPin) {
          setState(() {
            _error = 'Hai lần nhập chưa khớp. Hãy tạo lại.';
            _pin = '';
            _firstPin = '';
            _mode = _Mode.create;
          });
          return;
        }
        await _svc.setPin(
          _pin,
          recoveryQuestion:
              _recoveryQ.text.trim().isEmpty ? null : _recoveryQ.text.trim(),
          recoveryAnswer: _recoveryA.text,
        );
        if (mounted) _unlock();
        break;
      case _Mode.verify:
        final r = await _svc.verify(_pin);
        if (!mounted) return;
        switch (r.check) {
          case PinCheck.ok:
            _unlock();
            break;
          case PinCheck.wrong:
            setState(() {
              _pin = '';
              _error = 'Mã PIN chưa đúng. Còn ${r.remainingAttempts} lần thử.';
            });
            break;
          case PinCheck.lockedOut:
            setState(() {
              _pin = '';
              _error = null;
              _setLock(r.lockedUntil);
            });
            break;
          case PinCheck.notSet:
            setState(() => _mode = _Mode.create);
            break;
        }
        break;
      case _Mode.recover:
      case _Mode.loading:
        break;
    }
  }

  Future<void> _submitRecovery() async {
    final ok = await _svc.verifyRecovery(_recoveryA.text);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _mode = _Mode.create;
        _pin = '';
        _error = 'Đã xác minh. Hãy tạo mã PIN mới.';
        _recoveryA.clear();
      });
    } else {
      final locked = await _svc.lockedUntil();
      setState(() {
        _error = 'Câu trả lời chưa đúng.';
        _setLock(locked);
        if (locked != null) _mode = _Mode.verify;
      });
    }
  }

  String get _title {
    switch (_mode) {
      case _Mode.create:
        return 'Tạo mã PIN';
      case _Mode.confirm:
        return 'Nhập lại mã PIN';
      case _Mode.recover:
        return 'Khôi phục quyền truy cập';
      case _Mode.verify:
      case _Mode.loading:
        return 'Xác minh để tiếp tục';
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockSecs = _lockedUntil?.difference(DateTime.now()).inSeconds;
    return Scaffold(
      appBar: AppBar(title: const Text('Góc người chăm sóc')),
      body: SafeArea(
        child: _mode == _Mode.loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(Gap.m),
                children: [
                  const Text('Khu vực quản lý nội dung',
                      style: TextStyle(color: AppColors.muted)),
                  const SizedBox(height: Gap.m),
                  Container(
                    padding: const EdgeInsets.all(Gap.l),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: const BoxDecoration(
                            color: AppColors.accentBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock_outline_rounded,
                              size: 52, color: AppColors.primary),
                        ),
                        const SizedBox(height: Gap.m),
                        Text(_title,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: Gap.s),
                        Text(
                          _mode == _Mode.create
                              ? 'PIN gồm 4–6 chữ số, chỉ lưu dạng mã hóa trên máy này.'
                              : 'Nội dung và cài đặt được bảo vệ trong khu vực riêng.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: Gap.l),
                        if (_mode == _Mode.recover)
                          _recoveryForm()
                        else ...[
                          _PinDots(length: _pin.length),
                          const SizedBox(height: Gap.m),
                          if (lockSecs != null)
                            Text(
                              'Tạm khóa do nhập sai nhiều lần. Thử lại sau $lockSecs giây.',
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          if (_error != null)
                            Text(_error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          const SizedBox(height: Gap.m),
                          _Keypad(
                            enabled: _lockedUntil == null,
                            onDigit: _onDigit,
                            onBackspace: _onBackspace,
                          ),
                          if (_mode == _Mode.create) ...[
                            const SizedBox(height: Gap.m),
                            TextField(
                              controller: _recoveryQ,
                              decoration: const InputDecoration(
                                labelText:
                                    'Câu hỏi khôi phục (tùy chọn)',
                                hintText: 'Ví dụ: Tên thú cưng đầu tiên?',
                              ),
                            ),
                            const SizedBox(height: Gap.s),
                            TextField(
                              controller: _recoveryA,
                              decoration: const InputDecoration(
                                  labelText: 'Câu trả lời'),
                            ),
                          ],
                          const SizedBox(height: Gap.m),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _pin.length >= 4 &&
                                      _lockedUntil == null
                                  ? _submit
                                  : null,
                              child: const Text('Tiếp tục'),
                            ),
                          ),
                          if (_mode == _Mode.verify &&
                              _recoveryQuestion != null)
                            TextButton(
                              onPressed: _lockedUntil == null
                                  ? () => setState(() {
                                        _mode = _Mode.recover;
                                        _error = null;
                                      })
                                  : null,
                              child: const Text('Quên mã PIN?'),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: Gap.m),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Quay về giao diện trẻ'),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _recoveryForm() {
    return Column(
      children: [
        Text(_recoveryQuestion ?? '',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: Gap.s),
        TextField(
          controller: _recoveryA,
          decoration: const InputDecoration(labelText: 'Câu trả lời'),
        ),
        if (_error != null) ...[
          const SizedBox(height: Gap.s),
          Text(_error!),
        ],
        const SizedBox(height: Gap.m),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
              onPressed: _submitRecovery, child: const Text('Xác minh')),
        ),
        TextButton(
          onPressed: () => setState(() {
            _mode = _Mode.verify;
            _error = null;
          }),
          child: const Text('Nhập PIN'),
        ),
        const Text(
          'Nếu không nhớ câu trả lời: gỡ cài đặt ứng dụng sẽ xóa toàn bộ dữ liệu trên máy này.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      ],
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.length});
  final int length;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Đã nhập $length chữ số',
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < (length < 4 ? 4 : length); i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < length ? AppColors.primary : AppColors.border,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad(
      {required this.enabled,
      required this.onDigit,
      required this.onBackspace});
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, IconData? icon}) =>
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 60)),
              onPressed: enabled ? onTap : null,
              child: icon != null
                  ? Icon(icon, semanticLabel: label)
                  : Text(label, style: const TextStyle(fontSize: 24)),
            ),
          ),
        );
    Widget row(List<String> digits) => Row(
          children: [
            for (final d in digits) key(d, onTap: () => onDigit(d)),
          ],
        );
    return Column(
      children: [
        row(['1', '2', '3']),
        row(['4', '5', '6']),
        row(['7', '8', '9']),
        Row(
          children: [
            const Expanded(child: SizedBox()),
            key('0', onTap: () => onDigit('0')),
            key('Xóa', onTap: onBackspace, icon: Icons.backspace_outlined),
          ],
        ),
      ],
    );
  }
}
