# Story server – POST /api/v1/stories/generate

Máy chủ nhỏ (Node 18+, không framework) tạo **bản nháp** câu chuyện xã hội bằng Claude (`claude-opus-5-5`).
Khóa API chỉ nằm ở máy chủ – không bao giờ đóng gói trong ứng dụng (Mục 6.6, 8.4).

```bash
npm install
npm test
ANTHROPIC_API_KEY=sk-ant-... npm start
```

| Biến môi trường | Mặc định | Ý nghĩa |
|---|---|---|
| `ANTHROPIC_API_KEY` | – | Khóa Claude API |
| `PORT` | `8080` | Cổng |
| `MODEL` | `claude-opus-5-5` | Mô hình |
| `RATE_PER_MIN` | `10` | Giới hạn yêu cầu/phút/IP |
| `APP_TOKEN` | (trống) | Nếu đặt: yêu cầu header `X-App-Token` khớp |

## Hành vi

- Đầu vào: `scenario` 8–240 ký tự (chuẩn hóa NFC), `language` `vi`/`en`, `sensory_preferences` ≤ 5 × 1–80 ký tự; body ≤ 4 KB.
- Mô tả của người dùng được đặt trong thẻ `<event_description>` và coi là **dữ liệu**, không phải chỉ dẫn (chống prompt injection).
- Dùng structured output (JSON Schema, `icon` là enum danh sách cho phép), rồi **kiểm tra lại** độ dài, số bước 4–6, icon, cụm từ áp đặt/y khoa trước khi trả về. Luôn gắn `requires_review: true`, `source: "ai"`.
- Bật `fallbacks: "default"` (beta `server-side-fallback-2026-07-01`): nếu mô hình từ chối do bộ phân loại an toàn, API tự chạy lại trên mô hình dự phòng trong cùng lời gọi.
- Mã lỗi theo Bảng 18: 400, 413, 429 (+ `Retry-After`), 500, 502 (không có bản nháp hợp lệ), 503, 504 (hết 13s phía server; app chờ 15s).
- Mọi phản hồi có `X-Request-Id`. Nhật ký chỉ gồm mã yêu cầu, trạng thái, thời lượng, phiên bản app – **không** có nội dung mô tả hay khóa.
