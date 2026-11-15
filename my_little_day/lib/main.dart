import 'package:flutter/material.dart';

import 'app.dart';
import 'core/theme.dart';
import 'data/db/app_database.dart';
import 'data/models.dart';
import 'services/pin_service.dart';
import 'services/tts_service.dart';
import 'state/app_services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Bootstrap());
}

class _BootResult {
  _BootResult(this.services, this.settings);
  final AppServices services;
  final AppSettings settings;
}

/// Khởi động: mở CSDL cục bộ (không cần mạng – NFR-08), nạp thiết lập.
/// Nếu nâng cấp lược đồ thất bại → màn hình phục hồi rõ ràng (TC-24),
/// không tiếp tục ghi vào cấu trúc không nhất quán.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late Future<_BootResult> _boot = _start();

  Future<_BootResult> _start() async {
    final db = await AppDatabase.open();
    final speech = TtsService();
    await speech.init();
    final services = AppServices(
      db: db,
      speech: speech,
      pin: PinService(PlatformSecretStore()),
    );
    final settings = await services.settingsRepo.load();
    return _BootResult(services, settings);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootResult>(
      future: _boot,
      builder: (context, snap) {
        if (snap.hasData) {
          return MyLittleDayApp(
            services: snap.data!.services,
            initialSettings: snap.data!.settings,
          );
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: Scaffold(
            body: Center(
              child: snap.hasError
                  ? Padding(
                      padding: const EdgeInsets.all(Gap.l),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.storage_rounded,
                              size: 64, color: AppColors.primary),
                          const SizedBox(height: Gap.m),
                          const Text(
                            'Chưa mở được dữ liệu trên máy.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: Gap.s),
                          const Text(
                            'Dữ liệu hiện có được giữ nguyên. Có thể thử lại; nếu '
                            'vẫn lỗi, hãy cập nhật ứng dụng lên phiên bản mới nhất.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: Gap.l),
                          ElevatedButton(
                            onPressed: () => setState(() => _boot = _start()),
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
        );
      },
    );
  }
}
