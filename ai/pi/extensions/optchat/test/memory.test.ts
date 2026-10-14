import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, appendFileSync, writeFileSync, mkdirSync, readFileSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Memory, start, end, bytes, localDay, type Compression } from '../src/memory.ts';
import { lockProfile } from '../src/profiles.ts';
import { splitView, cachePayload } from '../src/cache.ts';
import { logMessage, buildContext, boundedMessage } from '../src/transcript.ts';
import { Inbox } from '../src/inbox.ts';
import type { ToolResultMessage } from '@earendil-works/pi-ai';
import type { AssistantMessage, SystemMessage, UserMessage } from '@earendil-works/pi-ai';

test('tree covers all history, fits incrementally, and exact originals survive restart', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'optchat-test-'));
  const calls: Compression[] = [];
  const compress = async (input: Compression) => { calls.push(input); return input.source.slice(0, 170); };
  let memory = new Memory(dir, compress, () => {}, 1500);
  try {
    for (let i = 0; i < 48; i++) memory.append('user', `Original ${i}: ${'valuable detail '.repeat(30)}`);
    await memory.settle(AbortSignal.timeout(5000), true);
    assert.equal(start(memory.view[0]), 0);
    assert.equal(end(memory.view.at(-1)!), 48);
    for (let i = 1; i < memory.view.length; i++) assert.equal(end(memory.view[i - 1]), start(memory.view[i]));
    assert.ok(memory.size <= 1500);
    assert.ok(memory.view.some(p => p.l > 0));
    assert.ok(calls.every(c => !c.context.includes('not summarized yet')));
    assert.match(memory.zoom(17, 1), /Original 17:/);
    const originals = memory.root.map(e => e.text);
    const parts = [...memory.view];
    memory.append('talk', 'One short new reply.');
    await memory.settle(AbortSignal.timeout(5000), true);
    for (const before of parts) assert.ok(memory.view.some(after => start(after) <= start(before) && end(after) >= end(before)));
    await memory.close();
    memory = new Memory(dir, compress, () => {}, 1500);
    await memory.settle(AbortSignal.timeout(5000), true);
    assert.deepEqual(memory.root.slice(0, 48).map(e => e.text), originals);
    assert.match(memory.zoom(17, 1), /valuable detail/);
    assert.throws(() => memory.zoom(3, 4), /No line/);
  } finally { await memory.close(); rmSync(dir, { recursive: true, force: true }); }
});

test('pending compaction blocks a turn, cancellation works, failure retries', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'optchat-test-')); let attempts = 0;
  const memory = new Memory(dir, async () => {
    attempts++; if (attempts === 1) throw new Error('temporary outage'); return 'user: retained decision';
  }, () => {}, 128000, 8, 100);
  try {
    memory.append('user', 'large message '.repeat(100));
    await assert.rejects(memory.settle(AbortSignal.timeout(20)), /cancelled/);
    await memory.settle(AbortSignal.timeout(2000));
    assert.equal(attempts, 2); assert.ok(memory.ready); assert.equal(memory.root.length, 1);
  } finally { await memory.close(); rmSync(dir, { recursive: true, force: true }); }
});

test('torn final line is reported and the next append remains readable', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'optchat-test-')); let memory = new Memory(dir, async () => 'summary');
  memory.append('user', 'first'); await memory.close();
  appendFileSync(join(dir, 'main', `${localDay()}.jsonl`), '{"torn":');
  const warnings: string[] = [];
  memory = new Memory(dir, async () => 'summary', text => warnings.push(text));
  memory.append('user', 'second'); await memory.close();
  memory = new Memory(dir, async () => 'summary', () => {});
  try { assert.equal(warnings.length, 1); assert.deepEqual(memory.root.map(e => e.text), ['first', 'second']); }
  finally { await memory.close(); rmSync(dir, { recursive: true, force: true }); }
});

test('a live profile cannot be opened by a second writer; other profiles can run', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'optchat-test-'));
  const unlock = await lockProfile(dir, 'test owner');
  try {
    await assert.rejects(lockProfile(dir, 'second writer'), /test owner/);
    const other = await lockProfile(dir + '-other', 'other profile'); await other();
  } finally { await unlock(); }
  const again = await lockProfile(dir, 'after close'); await again(); rmSync(dir, { recursive: true, force: true });
});

test('stable cache cuts preserve every character and cap marks at four', () => {
  const view = '<chat>\n' + '0+1|summary of a decision\n'.repeat(5500) + '</chat>';
  assert.equal(splitView(view).join(''), view);
  const payload = { system: [{ type: 'text', text: 'system', cache_control: { type: 'ephemeral' } }],
    messages: [{ role: 'user', content: [{ type: 'text', text: view }, { type: 'text', text: 'new question', cache_control: { type: 'ephemeral' } }] }],
  };
  const output = JSON.stringify(cachePayload(payload));
  assert.equal((output.match(/cache_control/g) ?? []).length, 4);
  assert.equal(payload.messages[0].content.map(b => b.text).join(''), view + 'new question');
});

test('next turn excludes old conversation; current tool loop and reasoning remain verbatim', async () => {
  const system: SystemMessage = { role: 'system', content: 'old system', timestamp: 0 };
  const old: UserMessage = { role: 'user', content: 'OLD FULL CONVERSATION', timestamp: 1 };
  const current: UserMessage = { role: 'user', content: 'new question', timestamp: 2 };
  const assistant: AssistantMessage = { role: 'assistant', content: [{ type: 'thinking', thinking: 'private thoughts', thinkingSignature: 'signed' }, { type: 'text', text: 'visible reply' }],
    api: 'anthropic-messages', provider: 'anthropic', model: 'fixture', stopReason: 'stop', timestamp: 3,
    usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } } };
  const projected = buildContext([system, old, current, assistant], [current, assistant], '<chat>\n0+1|old summary\n</chat>', 'new system');
  assert.ok(!JSON.stringify(projected).includes('OLD FULL CONVERSATION'));
  assert.equal(projected[2], assistant);
  const dir = mkdtempSync(join(tmpdir(), 'optchat-test-')); const memory = new Memory(dir, async () => 'summary');
  try { logMessage(memory, assistant); assert.equal(memory.root.length, 1); assert.equal(memory.root[0].text, 'visible reply'); }
  finally { await memory.close(); rmSync(dir, { recursive: true, force: true }); }
});

test('tool images survive active-context truncation while text is bounded', () => {
  const image = { type: 'image' as const, mimeType: 'image/png', data: 'example-base64' };
  const message: ToolResultMessage = { role: 'toolResult', toolCallId: 'read-1', toolName: 'read', isError: false, timestamp: 1,
    content: [{ type: 'text', text: 'x'.repeat(40_000) }, image] };
  const bounded = boundedMessage(message);
  assert.equal(bounded.role, 'toolResult');
  if (bounded.role !== 'toolResult') throw new Error('unexpected role');
  assert.ok(bounded.content.includes(image));
  assert.ok(bounded.content.filter(c => c.type === 'text').reduce((n, c) => n + c.text.length, 0) <= 30_000);
});

test('crash recovery saves unconsumed inputs once, including append-before-ack crash', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'optchat-test-'));
  const memory = new Memory(dir, async () => 'summary');
  try {
    let inbox = new Inbox(dir);
    inbox.record('queued while the agent was working');
    assert.equal(inbox.claim('unrelated extension message'), undefined);
    const delivered = inbox.record('delivered, but crashed before the journal acknowledgment');
    memory.append('user', 'delivered, but crashed before the journal acknowledgment', new Date().toISOString(), delivered);
    inbox = new Inbox(dir);
    assert.equal(inbox.recover(memory), 1);
    assert.equal(memory.root.length, 2);
    assert.equal(new Inbox(dir).recover(memory), 0);
    assert.equal(memory.root.length, 2);
  } finally { await memory.close(); rmSync(dir, { recursive: true, force: true }); }
});

// Synthetic persisted profiles: no real history, provider credentials, or model calls.
function seedView(dir: string, count: number, parts: { l: number; i: number }[],
  summaries: { l: number; i: number; text: string }[], savedCount = count, shrinking = false) {
  for (const sub of ['main', 'tree']) mkdirSync(join(dir, sub), { recursive: true });
  writeFileSync(join(dir, 'main', 'fixture.jsonl'), Array.from({ length: count }, (_, i) =>
    JSON.stringify({ i, kind: 'user', text: `original ${i}`, date: '2026-10-08T00:00:00Z' })).join('\n') + '\n');
  writeFileSync(join(dir, 'tree', 'fixture.jsonl'), summaries.map(s => JSON.stringify(s)).join('\n') + '\n');
  writeFileSync(join(dir, 'view.json'), JSON.stringify({ version: 1, count: savedCount, shrinking, parts }), { mode: 0o600 });
}

test('merge priority uses the last message, not the first (recipe T=10 counterexample)', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'optchat-priority-'));
  const summaries = Array.from({ length: 10 }, (_, i) => ({ l: 0, i, text: 'x'.repeat(100) }));
  summaries.push({ l: 2, i: 0, text: 'old A' }, { l: 2, i: 1, text: 'old B' },
    { l: 3, i: 0, text: 'old merged' }, { l: 1, i: 4, text: 'recent merged' });
  seedView(dir, 10, [{ l: 2, i: 0 }, { l: 2, i: 1 }, { l: 0, i: 8 }], summaries, 9);
  const memory = new Memory(dir, async () => 'summary', () => {}, 209);
  try {
    assert.deepEqual(memory.view, [{ l: 2, i: 0 }, { l: 2, i: 1 }, { l: 1, i: 4 }]);
    assert.ok(memory.size <= 104);
  } finally { await memory.close(); rmSync(dir, { recursive: true, force: true }); }
});

test('view grows untouched through 128KB, then batch shrinks to 64KB', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'optchat-batch-'));
  const parts = Array.from({ length: 250 }, (_, i) => ({ l: 0, i }));
  const summaries = Array.from({ length: 251 }, (_, i) => ({ l: 0, i, text: 'x'.repeat(512) }));
  for (let i = 0; i < 125; i++) summaries.push({ l: 1, i, text: 'p'.repeat(256) });
  seedView(dir, 250, parts, summaries.slice(0, 250).concat(summaries.slice(251)));
  const memory = new Memory(dir, async () => 'summary', () => {});
  try {
    assert.equal(memory.size, 128_000);
    assert.deepEqual(memory.view, parts);
    memory.append('user', 'new message');
    assert.ok(memory.size <= 64_000);
    assert.ok(memory.view.some(p => p.l === 1));
    assert.equal(end(memory.view.at(-1)!), 251);
  } finally { await memory.close(); rmSync(dir, { recursive: true, force: true }); }
});

test('an unfinished batch survives restart and resumes when missing parents are built', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'optchat-resume-batch-'));
  const summaries = Array.from({ length: 6 }, (_, i) => ({ l: 0, i, text: 'x'.repeat(450) }));
  summaries.push({ l: 1, i: 0, text: 'p'.repeat(100) }, { l: 1, i: 1, text: 'p'.repeat(100) });
  seedView(dir, 6, Array.from({ length: 5 }, (_, i) => ({ l: 0, i })), summaries, 5);
  let memory = new Memory(dir, async () => 'p'.repeat(100), () => {}, 2000);
  try {
    assert.equal(memory.size, 1100); // Below high-water mark, but still above batch target.
    assert.equal(JSON.parse(readFileSync(join(dir, 'view.json'), 'utf8')).shrinking, true);
    const parts = structuredClone(memory.view);
    await memory.close();
    memory = new Memory(dir, async () => 'p'.repeat(100), () => {}, 2000);
    assert.deepEqual(memory.view, parts);
    await memory.settle(AbortSignal.timeout(5000), true);
    assert.ok(memory.size <= 1000);
    assert.equal(JSON.parse(readFileSync(join(dir, 'view.json'), 'utf8')).shrinking, false);
  } finally { await memory.close(); rmSync(dir, { recursive: true, force: true }); }
});

test('restart restores exact saved view despite additional cached summaries; suffix recovers once', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'optchat-exact-view-'));
  const parts = [{ l: 1, i: 0 }, { l: 0, i: 2 }, { l: 0, i: 3 }];
  const summaries = Array.from({ length: 4 }, (_, i) => ({ l: 0, i, text: `summary ${i}` }));
  summaries.push({ l: 1, i: 0, text: 'saved older pair' }, { l: 1, i: 1, text: 'another pair' },
    { l: 2, i: 0, text: 'whole history' });
  seedView(dir, 4, parts, summaries);
  let memory = new Memory(dir, async () => 'summary', () => {});
  try {
    const rendered = memory.render();
    assert.deepEqual(memory.view, parts);
    await memory.close();
    memory = new Memory(dir, async () => 'summary', () => {});
    assert.equal(memory.render(), rendered);
    assert.equal(statSync(join(dir, 'view.json')).mode & 0o777, 0o600);
    await memory.close();
    // Simulate crash after durable log append but before the view checkpoint.
    appendFileSync(join(dir, 'main', 'fixture.jsonl'), JSON.stringify({ i: 4, kind: 'user',
      text: 'crash suffix', date: '2026-10-08T00:00:00Z' }) + '\n');
    memory = new Memory(dir, async () => 'summary', () => {});
    assert.deepEqual(memory.view, [...parts, { l: 0, i: 4 }]);
    assert.equal(memory.root[4].text, 'crash suffix');
    await memory.close();
    memory = new Memory(dir, async () => 'summary', () => {});
    assert.deepEqual(memory.view, [...parts, { l: 0, i: 4 }]);
  } finally { await memory.close(); rmSync(dir, { recursive: true, force: true }); }
});

test('legacy and corrupt checkpoints recover with warnings without changing authoritative log', async () => {
  for (const checkpoint of [undefined, '{broken', JSON.stringify({ version: 1, count: 2,
    shrinking: false, parts: [{ l: 0, i: 1 }] })]) {
    const dir = mkdtempSync(join(tmpdir(), 'optchat-checkpoint-recovery-'));
    mkdirSync(join(dir, 'main'));
    const file = join(dir, 'main', 'fixture.jsonl');
    const log = [0, 1].map(i => JSON.stringify({ i, kind: 'user', text: `original ${i}`,
      date: '2026-10-08T00:00:00Z' })).join('\n') + '\n';
    writeFileSync(file, log);
    if (checkpoint !== undefined) writeFileSync(join(dir, 'view.json'), checkpoint);
    const warnings: string[] = [];
    const memory = new Memory(dir, async () => 'summary', text => warnings.push(text));
    try {
      assert.equal(warnings.length, 1);
      assert.deepEqual(memory.view, [{ l: 0, i: 0 }, { l: 0, i: 1 }]);
      assert.equal(readFileSync(file, 'utf8'), log);
      assert.equal(JSON.parse(readFileSync(join(dir, 'view.json'), 'utf8')).count, 2);
    } finally { await memory.close(); rmSync(dir, { recursive: true, force: true }); }
  }
});


test('equally due pairs merge oldest first', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'optchat-tie-'));
  const summaries = Array.from({ length: 7 }, (_, i) => ({ l: 0, i, text: i === 6 ? 'z' : 'x'.repeat(10) }));
  summaries.push({ l: 1, i: 0, text: 'a'.repeat(40) }, { l: 1, i: 1, text: 'b'.repeat(40) },
    { l: 2, i: 0, text: 'old' }, { l: 1, i: 2, text: 'recent' });
  seedView(dir, 7, [{ l: 1, i: 0 }, { l: 1, i: 1 }, { l: 0, i: 4 }, { l: 0, i: 5 }], summaries, 6);
  const memory = new Memory(dir, async () => 'summary', () => {}, 100);
  try {
    assert.deepEqual(memory.view, [{ l: 2, i: 0 }, { l: 0, i: 4 }, { l: 0, i: 5 }, { l: 0, i: 6 }]);
  } finally { await memory.close(); rmSync(dir, { recursive: true, force: true }); }
});

test('below the high-water mark, newly available parents do not rewrite the view', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'optchat-prefix-'));
  const summaries = Array.from({ length: 4 }, (_, i) => ({ l: 0, i, text: 'x'.repeat(200) }));
  const parts = summaries.map(({ l, i }) => ({ l, i }));
  seedView(dir, 4, parts, summaries);
  const memory = new Memory(dir, async () => 'summary', () => {}, 1000);
  try {
    const before = memory.render();
    await memory.settle(AbortSignal.timeout(5000), true);
    assert.equal(memory.render(), before);
    memory.append('talk', 'small reply');
    await memory.settle(AbortSignal.timeout(5000), true);
    assert.deepEqual(memory.view.slice(0, 4), parts);
    assert.ok(memory.render().startsWith(before.slice(0, -'</chat>'.length)));
  } finally { await memory.close(); rmSync(dir, { recursive: true, force: true }); }
});

test('restart resumes a batch if the tree write beat the view checkpoint before a crash', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'optchat-tree-ahead-'));
  const summaries = Array.from({ length: 4 }, (_, i) => ({ l: 0, i, text: 'x'.repeat(200) }));
  summaries.push({ l: 1, i: 0, text: 'old' }, { l: 1, i: 1, text: 'recent' }, { l: 2, i: 0, text: 'all' });
  seedView(dir, 4, Array.from({ length: 4 }, (_, i) => ({ l: 0, i })), summaries, 4, true);
  const memory = new Memory(dir, async () => { throw new Error('all summaries already exist'); }, () => {}, 1000);
  try {
    assert.ok(memory.size <= 500);
    assert.equal(JSON.parse(readFileSync(join(dir, 'view.json'), 'utf8')).shrinking, false);
    await memory.settle(AbortSignal.timeout(5000), true);
  } finally { await memory.close(); rmSync(dir, { recursive: true, force: true }); }
});
