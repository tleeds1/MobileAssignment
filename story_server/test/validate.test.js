import assert from 'node:assert/strict';
import { test } from 'node:test';

import { findForbidden, validateDraft, validateRequest } from '../src/validate.js';

const good = () => ({
  title: 'Con sẽ đến phòng khám',
  steps: [
    { text: 'Con sẽ đến phòng khám cùng người chăm sóc.', icon: 'car' },
    { text: 'Có thể có người nói chuyện và thiết bị.', icon: 'doctor' },
    { text: 'Con có thể dùng thẻ nghỉ hoặc nhờ giúp đỡ.', icon: 'rest' },
    { text: 'Khi xong, con sẽ rời phòng khám.', icon: 'done' },
  ],
  caregiver_tip: 'Người chăm sóc cần điều chỉnh nội dung theo thực tế.',
});

test('validateRequest: hợp lệ, chuẩn hóa và bỏ trường lạ', () => {
  const r = validateRequest({
    scenario: '  Con sẽ đi khám cùng người chăm sóc.  ',
    language: 'vi',
    sensory_preferences: ['Con muốn biết trước các bước'],
    extra: 'ignored',
  });
  assert.equal(r.ok, true);
  assert.equal(r.value.scenario, 'Con sẽ đi khám cùng người chăm sóc.');
  assert.equal('extra' in r.value, false);
});

test('validateRequest: giới hạn độ dài, ngôn ngữ, số lưu ý', () => {
  assert.equal(validateRequest({ scenario: 'ngắn' }).ok, false);
  assert.equal(validateRequest({ scenario: 'x'.repeat(241) }).ok, false);
  assert.equal(validateRequest({ scenario: 'Con sẽ đi khám.', language: 'fr' }).ok, false);
  assert.equal(
    validateRequest({ scenario: 'Con sẽ đi khám.', sensory_preferences: Array(6).fill('a') }).ok,
    false,
  );
  assert.equal(validateRequest(null).ok, false);
});

test('validateDraft: hợp lệ → luôn requires_review + source ai', () => {
  const r = validateDraft({ ...good(), extra: 'x' });
  assert.equal(r.ok, true);
  assert.equal(r.value.requires_review, true);
  assert.equal(r.value.source, 'ai');
  assert.equal('extra' in r.value, false);
});

test('validateDraft: icon lạ, số bước sai, thiếu tip bị từ chối', () => {
  const a = good();
  a.steps[0].icon = 'rocket';
  assert.equal(validateDraft(a).ok, false);
  const b = good();
  b.steps = b.steps.slice(0, 3);
  assert.equal(validateDraft(b).ok, false);
  const c = good();
  delete c.caregiver_tip;
  assert.equal(validateDraft(c).ok, false);
});

test('validateDraft: chặn nội dung áp đặt / y khoa', () => {
  const d = good();
  d.steps[1].text = 'Con phải ngồi yên khi bác sĩ khám.';
  assert.equal(validateDraft(d).ok, false);
  assert.deepEqual(findForbidden('Có những người ở đó.'), []);
});
