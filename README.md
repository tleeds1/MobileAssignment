# My Little Day – mã nguồn

Ứng dụng di động hỗ trợ trẻ tự kỷ trong sinh hoạt và giao tiếp (CO3043 – BTL1).
Hiện thực theo `MyLittleDay_App_Specification_v0_6` và các góp ý trong `my little day.docx`.

```
Mobile/
├── my_little_day/   Ứng dụng Flutter (Android + iOS) – 5 phân hệ M1–M5, dữ liệu cục bộ
└── story_server/    API Node.js: POST /api/v1/stories/generate (Claude) – giữ khóa AI ở máy chủ
```

## Chạy nhanh

```bash
# Ứng dụng (Flutter 3.3+, Dart 2.18+)
cd my_little_day
flutter pub get
flutter test          # 51 kiểm thử: quy tắc nghiệp vụ, repository, API client, PIN
flutter run           # cần Android SDK / Xcode và một thiết bị hoặc emulator

# Máy chủ AI (Node 18+) – tùy chọn; không có máy chủ, ứng dụng vẫn dùng mẫu cục bộ
cd story_server
npm install
npm test              # 9 kiểm thử
ANTHROPIC_API_KEY=... npm start     # cổng 8080
```

Trong ứng dụng: **Góc người chăm sóc › Dữ liệu & quyền riêng tư › Địa chỉ máy chủ**
(emulator Android: `http://10.0.2.2:8080`; máy chủ thật bắt buộc `https://`).

## Mở Góc người chăm sóc

Không có nút cài đặt trên giao diện trẻ. **Nhấn giữ tiêu đề màn hình (ví dụ "Lịch của con") 3 giây** → nhập PIN.
Lần đầu mở ứng dụng có màn hình hướng dẫn và tạo PIN.

## Kiến trúc (Mục 6.2)

| Tầng | Thư mục | Nội dung |
|---|---|---|
| Trình bày | `lib/ui/` | `child/` (Lịch, Giao tiếp, Cảm xúc, Truyện), `caregiver/` (PIN, bảng điều khiển, biên tập), `widgets/` |
| Trạng thái | `lib/state/` | `ChangeNotifier` + `provider`; phiên người chăm sóc tự khóa |
| Nghiệp vụ | `lib/domain/` | `schedule_logic` (hiện tại/kế tiếp), `story_lifecycle` (nháp ↔ duyệt), `story_validator` |
| Dữ liệu | `lib/data/`, `lib/services/` | SQLite có phiên bản lược đồ + migration, repository, TTS, PIN, ảnh, API client |

Chi tiết ánh xạ yêu cầu → mã nguồn: xem `my_little_day/README.md`.
