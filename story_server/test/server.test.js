import assert from 'node:assert/strict';
import http from 'node:http';
import { after, before, test } from 'node:test';

import { GenerationError } from '../src/generator.js';
import { handle } from '../src/server.js';

let mode = 'ok';
const fakeGenerate = async () => {
  if (mode === 'timeout') throw new GenerationError('timeout');
  if (mode === 'down') throw new GenerationError('upstream_unavailable');
  if (mode === 'bad') {
    return { title: 'X', steps: [], caregiver_tip: 'tip' };
  }
  return {
    title: 'Con sẽ đến phòng khám',
    steps: [
      { text: 'Con sẽ đến phòng khám.', icon: 'car' },
      { text: 'Con ngồi chờ cùng người lớn.', icon: 'clock' },
      { text: 'Bác sĩ có thể nói chuyện với con.', icon: 'doctor' },
      { text: 'Xong rồi, con về nhà.', icon: 'home' },
    ],
    caregiver_tip: 'Hãy chỉnh theo phòng khám thực tế.',
  };
};

let server;
let base;
before(async () => {
  server = http.createServer((req, res) => handle(req, res, { generate: fakeGenerate }));
  await new Promise((r) => server.listen(0, r));
  base = `http://127.0.0.1:${server.address().port}`;
});
after(() => server.close());

const post = (body) =>
  fetch(`${base}/api/v1/stories/generate`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });

const valid = { scenario: 'Con sẽ đi khám cùng mẹ.', language: 'vi', sensory_preferences: [] };

test('200: bản nháp hợp lệ có X-Request-Id', async () => {
  mode = 'ok';
  const r = await post(valid);
  assert.equal(r.status, 200);
  assert.ok(r.headers.get('x-request-id'));
  const j = await r.json();
  assert.equal(j.requires_review, true);
  assert.equal(j.steps.length, 4);
});

test('400 / 413', async () => {
  assert.equal((await post({ scenario: 'ngắn' })).status, 400);
  assert.equal((await post('{not json')).status, 400);
  assert.equal((await post({ scenario: 'x'.repeat(5000) })).status, 413);
});

test('504 / 503 / 502 khi mô hình lỗi hoặc trả bản nháp không hợp lệ', async () => {
  mode = 'timeout';
  assert.equal((await post(valid)).status, 504);
  mode = 'down';
  assert.equal((await post(valid)).status, 503);
  mode = 'bad';
  assert.equal((await post(valid)).status, 502);
});

test('405 với phương thức khác POST', async () => {
  const r = await fetch(`${base}/api/v1/stories/generate`);
  assert.equal(r.status, 405);
});
