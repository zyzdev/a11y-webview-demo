// Node 版的自我測試執行器。用法：node web/test/run.mjs
// 跑的是和 test/index.html 同一份 tests.js；有失敗時 exit code 為 1。
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const require = createRequire(import.meta.url);

let count = 0;
const failures = [];

function deepEqual(a, b) {
  if (a === b) return true;
  if (typeof a !== 'object' || typeof b !== 'object' || a === null || b === null) return false;
  if (Array.isArray(a) !== Array.isArray(b)) return false;
  const keysA = Object.keys(a);
  const keysB = Object.keys(b);
  if (keysA.length !== keysB.length) return false;
  return keysA.every((key) => Object.prototype.hasOwnProperty.call(b, key) && deepEqual(a[key], b[key]));
}

// tests.js 只認得全域的 eq 和 A11yCore。
globalThis.eq = (actual, expected) => {
  count += 1;
  if (!deepEqual(actual, expected)) {
    failures.push(`FAIL: 第 ${count} 條：預期 ${JSON.stringify(expected)}，實際 ${JSON.stringify(actual)}`);
  }
};

try {
  globalThis.A11yCore = require('../shared/a11y-app.js').A11yCore;
  const testsFile = fileURLToPath(new URL('./tests.js', import.meta.url));
  vm.runInThisContext(readFileSync(testsFile, 'utf8'), { filename: testsFile });
} catch (error) {
  failures.push(`FAIL: 測試在第 ${count} 條之後中斷：${error && error.message ? error.message : error}`);
}

// 一條斷言都沒跑到不能算通過：tests.js 變成空檔或沒有呼叫 eq 時，要明確失敗。
if (failures.length === 0 && count === 0) {
  failures.push('FAIL: 沒有執行任何斷言（tests.js 是空的，或裡面沒有呼叫 eq）');
}

console.log(failures.length > 0 ? failures.join('\n') : `ALL PASS (${count})`);
process.exitCode = failures.length > 0 ? 1 : 0;
