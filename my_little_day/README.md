# My Little Day – ứng dụng Flutter

Viết tương thích **Flutter 3.3.10 / Dart 2.18** (không dùng records, patterns, `FilledButton`, `context.mounted`).
Nếu nâng Flutter, các API này vẫn chạy bình thường.

## Ánh xạ đặc tả → mã nguồn

| Yêu cầu | Hiện thực |
|---|---|
| **M1** FR-M1-01..12, UC-CH-02/03 | `ui/child/schedule_screen.dart`, `domain/schedule_logic.dart`, `ui/caregiver/schedule_editor_screen.dart` |
| Trạng thái theo ngày (BR-02, BR-09) | bảng `activity_completions` UNIQUE(activityId, localDate); `ScheduleController.ensureToday()` |
| Không suy "hiện tại" theo giờ khi thiếu giờ (FR-M1-11) | `ScheduleLogic.build` – chỉ dùng đồng hồ khi bật và mọi hoạt động còn lại đều có giờ |
| Báo thay đổi lịch: đổi/hoãn/hủy/thay/chưa xác định (FR-M1-12) | bảng `schedule_changes`, dải "Hôm nay lịch có thay đổi" + bảng "Phần thay đổi / Phần giữ nguyên" |
| **M2** FR-M2-01..10, UC-CH-01 | `ui/child/communication_screen.dart`, `state/card_controller.dart`, `ui/caregiver/card_editor_screen.dart` |
| Thẻ ưu tiên ≤ 2 thao tác (FR-M2-09) | nút trợ giúp nổi `ui/child/quick_help_sheet.dart` |
| **M3** FR-M3-01..07, UC-CH-04 | `ui/child/emotion_screen.dart` – bỏ qua/“Con chưa biết” không tạo bản ghi; chỉ ghi khi bật lưu |
| **M4** FR-M4-01..11, UC-CG-02, UC-CH-05 | `ui/caregiver/story_*`, `ui/child/story_reader_screen.dart`, `services/story_api_client.dart`, `services/local_story_templates.dart` |
| Chỉ truyện đã duyệt hiện cho trẻ; sửa → về nháp (BR-04, BR-05) | `domain/story_lifecycle.dart`, `StoryController.approved` |
| **M5** FR-M5-01..08, UC-CG-01/03 | `ui/caregiver/*` – PIN có khóa tạm + câu hỏi khôi phục, phiên tự khóa, thiết lập có xem trước, xuất JSON, xóa mẫu, đặt lại (gõ "XÓA") |
| NFR tiếp cận | vùng chạm ≥ 48dp, nhãn ngữ nghĩa "Thẻ: …", trạng thái luôn có chữ + biểu tượng, cỡ chữ tới 130%, giảm chuyển động |
| Ngoại tuyến (NFR-08/09) | mọi chức năng lõi dùng SQLite cục bộ; lỗi AI không ảnh hưởng phân hệ khác |
| Riêng tư (Mục 8) | không cần tên/ngày sinh; cảnh báo PII trước khi gửi AI; `allowBackup=false`; ảnh lưu vùng riêng |

## Các góp ý review đã đưa vào

| Góp ý | Cách làm |
|---|---|
| Ghép câu kiểu AAC: CON MUỐN + UỐNG + NƯỚC CAM | Thanh ghép câu trên M2 (bật/tắt trong thiết lập), nút "Nói" / "Cho xem" |
| Mã màu Fitzgerald Key cho thẻ | 7 nhóm màu viền dày + **biểu tượng hình dạng** ở góc (màu không là tín hiệu duy nhất); thẻ khẩn cấp có nền ấm |
| Gõ liên thanh gây TTS chồng tiếng | `TapGuard` + TTS luôn `stop()` trước khi nói, bỏ qua câu lặp trong 1,5s |
| Nút "Xong rồi" phẳng, dễ chạm nhầm | Nút nổi khối có bóng, **giữ ~1s** với thanh "gạt công tắc"; thẻ hiện tại **trượt xuống hộp "Đã xong"**, thẻ kế tiếp trượt lên; có Hoàn tác |
| Thanh "Con cần giúp" dễ trượt tay sang tab | Thay bằng **nút tròn nổi ở góc trên** |
| Dải "Giọng đọc: Bật" thừa trên giao diện trẻ | Đã bỏ; trạng thái TTS chỉ ở thiết lập |
| Đổi 4/6/8 thẻ làm xáo trộn vị trí | Thẻ có `position` cố định, chỉ chia lại trang; thẻ "tạm ẩn" để lại ô trống |
| Emoji cảm xúc trừu tượng | Tab **"Cơ thể"** (đau đầu, nóng người, muốn hét, bụng cồn cào); người chăm sóc thay bằng **ảnh thật** |
| Sau khi chọn "Khó chịu" thì sao? | Gợi ý xoa dịu: thẻ Nghỉ / Giúp con / Thở chậm / Dùng thẻ để nói (trẻ có thể từ chối) |
| "Câu chuyện xã hội", 1 câu ngắn/bước | Đổi tên; AI được yêu cầu 1 câu ≤ 15 từ; trình biên tập cảnh báo câu dài/nhiều câu |
| Icon chữ thập vô nghĩa – cần ảnh thật | Mỗi bước truyện, thẻ, hoạt động, cảm xúc đều cho chọn/chụp ảnh |
| Nút Quay lại/Tiếp theo nhỏ | **Vuốt ngang** để lật trang + nút cao 64dp |
| Lối vào Góc người chăm sóc bị ẩn hoàn toàn | **Nhấn giữ tiêu đề 3 giây** (có hành động riêng cho TalkBack/VoiceOver), hướng dẫn ở màn hình chào |
| Đổi tab liên tục (visual stimming) | Chặn đổi tab < 0,8s, không hiệu ứng chuyển tab; **Khóa màn hình tập trung** ẩn thanh điều hướng |
| Thiếu dữ liệu cho IEP | **Ghi tần suất dùng thẻ** (mặc định tắt, giải thích mục đích) + thống kê theo thẻ và khung giờ – chỉ mô tả |
| Âm báo lỗi chói tai | Ứng dụng không phát bất kỳ âm báo lỗi nào; chỉ TTS theo thao tác chủ động |

## Lưu ý trước khi phát hành (theo Mục 8.4, 10.4)

- **Mã hóa CSDL**: hiện dùng `sqflite` thường; mở CSDL tập trung ở `data/db/app_database.dart` để thay bằng `sqflite_sqlcipher` + khóa trong secure storage.
- **Sinh trắc học**: đặc tả cho phép PIN *hoặc* sinh trắc; bản này dùng PIN (có `PinService` để bổ sung `local_auth`).
- **Xác thực app ↔ server**: đặc tả chưa chốt; server hỗ trợ tạm `APP_TOKEN`.
- Bộ biểu tượng hiện dùng Material Icons (giấy phép Apache 2.0) – cần kiểm tra độ dễ hiểu với gia đình.
