// Kiểm tra đầu vào / đầu ra theo Mục 6.6 và 7.4–7.5 của đặc tả.
// Giữ đồng bộ với lib/domain/story_validator.dart trong ứng dụng.

export const ICON_ALLOWLIST = [
  'home', 'ear', 'parent', 'clock', 'rest', 'person', 'car',
  'doctor', 'scissors', 'smile', 'book', 'water', 'school', 'done',
];

export const LIMITS = {
  maxBodyBytes: 4096,
  scenario: [8, 240],
  maxPrefs: 5,
  pref: [1, 80],
  title: [3, 70],
  steps: [4, 6],
  step: [3, 160],
  tip: [3, 240],
};

const FORBIDDEN = [
  'chẩn đoán', 'điều trị', 'trị liệu', 'uống thuốc', 'con phải', 'bắt buộc',
  'không được khóc', 'phải ngồi yên', 'phải nhìn', 'nhìn vào mắt',
  'con sẽ cảm thấy', 'con sẽ thấy vui', 'con sẽ không sợ', 'ngoan', 'hư',
  'bị phạt', 'trừng phạt', 'thất bại',
  // en
  'diagnos', 'treatment', 'you must', 'you will feel', 'good boy', 'good girl',
  'punish', 'make eye contact',
];

const len = (s) => [...s].length; // đếm theo code point, không theo UTF-16

function inRange(s, [min, max]) {
  return typeof s === 'string' && len(s.trim()) >= min && len(s.trim()) <= max;
}

export function findForbidden(text) {
  const lower = ` ${text.toLowerCase()} `;
  return FORBIDDEN.filter((f) => {
    const esc = f.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    return new RegExp(`(^|[\\s,.!?;:"“”])${esc}`, 'u').test(lower);
  });
}

/** @returns {{ok: true, value: object} | {ok: false, errors: string[]}} */
export function validateRequest(body) {
  const errors = [];
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return { ok: false, errors: ['body must be a JSON object'] };
  }
  const scenario =
    typeof body.scenario === 'string' ? body.scenario.normalize('NFC').trim() : null;
  if (!scenario || !inRange(scenario, LIMITS.scenario)) {
    errors.push('scenario must be 8-240 characters');
  }
  const language = body.language ?? 'vi';
  if (language !== 'vi' && language !== 'en') {
    errors.push('language must be "vi" or "en"');
  }
  const prefsRaw = body.sensory_preferences ?? [];
  let prefs = [];
  if (!Array.isArray(prefsRaw) || prefsRaw.length > LIMITS.maxPrefs) {
    errors.push('sensory_preferences must be an array of at most 5 items');
  } else {
    prefs = prefsRaw.map((p) => (typeof p === 'string' ? p.normalize('NFC').trim() : ''));
    if (prefs.some((p) => !inRange(p, LIMITS.pref))) {
      errors.push('each sensory preference must be 1-80 characters');
    }
  }
  // Bỏ qua mọi trường khác – không chuyển tiếp cho mô hình.
  if (errors.length) return { ok: false, errors };
  return { ok: true, value: { scenario, language, sensory_preferences: prefs } };
}

/**
 * Xác thực đầu ra mô hình. Không coi là hợp lệ chỉ vì có dạng JSON.
 * Trả về đối tượng đã lọc (chỉ các trường được hỗ trợ).
 */
export function validateDraft(draft) {
  const errors = [];
  if (!draft || typeof draft !== 'object') {
    return { ok: false, errors: ['draft is not an object'] };
  }
  if (!inRange(draft.title, LIMITS.title)) errors.push('invalid title');

  const steps = Array.isArray(draft.steps) ? draft.steps : null;
  if (!steps || steps.length < LIMITS.steps[0] || steps.length > LIMITS.steps[1]) {
    errors.push('steps must contain 4-6 items');
  } else {
    steps.forEach((s, i) => {
      if (!s || !inRange(s.text, LIMITS.step)) errors.push(`invalid step ${i} text`);
      if (!s || !ICON_ALLOWLIST.includes(s.icon)) errors.push(`invalid step ${i} icon`);
    });
  }
  if (!inRange(draft.caregiver_tip, LIMITS.tip)) errors.push('invalid caregiver_tip');

  if (!errors.length) {
    const childText = [draft.title, ...steps.map((s) => s.text)];
    const bad = [...new Set(childText.flatMap(findForbidden))];
    if (bad.length) errors.push(`disallowed phrasing: ${bad.join(', ')}`);
  }
  if (errors.length) return { ok: false, errors };

  return {
    ok: true,
    value: {
      title: draft.title.trim(),
      steps: steps.map((s) => ({ text: s.text.trim(), icon: s.icon })),
      caregiver_tip: draft.caregiver_tip.trim(),
      requires_review: true, // luôn cần người chăm sóc duyệt
      source: 'ai',
    },
  };
}
