import { randomUUID } from 'node:crypto';
import http from 'node:http';

import { GenerationError, generateDraft } from './generator.js';
import { LIMITS, validateDraft, validateRequest } from './validate.js';

const PORT = Number(process.env.PORT || 8080);
// Xác thực ứng dụng ↔ máy chủ chưa được chốt trong đặc tả (Mục 6.6, 10.4).
// Tạm thời: nếu đặt APP_TOKEN, mọi yêu cầu phải gửi header X-App-Token khớp.
const APP_TOKEN = process.env.APP_TOKEN || '';
const RATE_PER_MIN = Number(process.env.RATE_PER_MIN || 10);

// ---- Giới hạn tần suất đơn giản theo IP (cửa sổ trượt 60 giây) -------------
const hits = new Map();
function rateLimited(ip) {
  const now = Date.now();
  const recent = (hits.get(ip) || []).filter((t) => now - t < 60_000);
  if (recent.length >= RATE_PER_MIN) {
    hits.set(ip, recent);
    return Math.ceil((60_000 - (now - recent[0])) / 1000);
  }
  recent.push(now);
  hits.set(ip, recent);
  return 0;
}
setInterval(() => {
  const now = Date.now();
  for (const [ip, list] of hits) {
    if (!list.some((t) => now - t < 60_000)) hits.delete(ip);
  }
}, 60_000).unref();

// ---- Tiện ích -----------------------------------------------------------------
function send(res, status, body, headers = {}) {
  const payload = Buffer.from(JSON.stringify(body), 'utf8');
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': payload.length,
    'Cache-Control': 'no-store',
    ...headers,
  });
  res.end(payload);
}

/** Nhật ký KHÔNG chứa nội dung yêu cầu, khóa API hay dữ liệu cá nhân (NFR-14). */
function log(requestId, status, startedAt, appVersion, kind) {
  console.log(
    JSON.stringify({
      requestId,
      status,
      ms: Date.now() - startedAt,
      appVersion: appVersion || null,
      ...(kind ? { kind } : {}),
    }),
  );
}

const HARD_CAP_BYTES = 1024 * 1024;

function readBody(req) {
  return new Promise((resolve, reject) => {
    const tooLarge = () => Object.assign(new Error('too large'), { code: 413 });
    const declared = Number(req.headers['content-length'] || 0);
    let size = 0;
    let over = declared > LIMITS.maxBodyBytes;
    const chunks = [];
    req.on('data', (c) => {
      size += c.length;
      if (size > LIMITS.maxBodyBytes) over = true;
      if (size > HARD_CAP_BYTES) {
        req.destroy(); // chặn tải quá lớn
        return;
      }
      if (!over) chunks.push(c); // vượt giới hạn: chỉ xả, không lưu
    });
    req.on('end', () =>
      over ? reject(tooLarge()) : resolve(Buffer.concat(chunks).toString('utf8')),
    );
    req.on('error', reject);
  });
}

// ---- Handler ------------------------------------------------------------------
export async function handle(req, res, { generate = generateDraft } = {}) {
  const requestId = randomUUID();
  const startedAt = Date.now();
  const appVersion = req.headers['x-app-version'];
  const headers = { 'X-Request-Id': requestId };
  const done = (status, body, extra = {}, kind) => {
    send(res, status, body, { ...headers, ...extra });
    log(requestId, status, startedAt, appVersion, kind);
  };

  if (req.method === 'GET' && req.url === '/healthz') {
    return done(200, { ok: true });
  }
  if (req.url !== '/api/v1/stories/generate') {
    return done(404, { error: 'not_found' });
  }
  if (req.method !== 'POST') {
    return done(405, { error: 'method_not_allowed' }, { Allow: 'POST' });
  }
  if (APP_TOKEN && req.headers['x-app-token'] !== APP_TOKEN) {
    return done(401, { error: 'unauthorized' });
  }
  const ip = req.socket.remoteAddress || 'unknown';
  const retryAfter = rateLimited(ip);
  if (retryAfter) {
    return done(429, { error: 'rate_limited' }, { 'Retry-After': String(retryAfter) });
  }

  let raw;
  try {
    raw = await readBody(req);
  } catch (e) {
    if (e.code === 413) return done(413, { error: 'payload_too_large' });
    return done(400, { error: 'bad_request' });
  }
  let body;
  try {
    body = JSON.parse(raw);
  } catch {
    return done(400, { error: 'invalid_json' });
  }
  const input = validateRequest(body);
  if (!input.ok) {
    return done(400, { error: 'invalid_input', details: input.errors });
  }

  let draft;
  try {
    draft = await generate(input.value);
  } catch (e) {
    if (e instanceof GenerationError) {
      if (e.kind === 'timeout') return done(504, { error: 'timeout' }, {}, e.kind);
      if (e.kind === 'upstream_unavailable') {
        return done(503, { error: 'unavailable' }, {}, e.kind);
      }
      // refusal / invalid_json / upstream_error → không có bản nháp hợp lệ.
      return done(502, { error: 'no_valid_draft' }, {}, e.kind);
    }
    return done(500, { error: 'internal_error', request_id: requestId }, {}, 'exception');
  }

  const out = validateDraft(draft);
  if (!out.ok) {
    // Không trả nội dung chưa qua kiểm tra; ứng dụng sẽ đề xuất mẫu cục bộ.
    return done(502, { error: 'no_valid_draft' }, {}, 'invalid_output');
  }
  return done(200, out.value);
}

export function createServer() {
  return http.createServer((req, res) => {
    handle(req, res).catch(() => {
      if (!res.headersSent) send(res, 500, { error: 'internal_error' });
    });
  });
}

export { PORT };
