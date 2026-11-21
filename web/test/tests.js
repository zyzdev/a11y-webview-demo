// 網頁自我測試：A11yCore（shared/a11y-app.js 的純函式部分）。
// 只用全域的 A11yCore 和 eq(實際值, 預期值)，不依賴執行環境。
// 瀏覽器用 test/index.html 執行，Node 用 `node web/test/run.mjs` 執行，兩邊跑的是同一份。

// --- parseParams：預設值 ---
eq(A11yCore.parseParams(''), {mode:'fixed', off:[], embedded:false, lang:null, theme:null, textScale:null, bold:null, contrast:null, reduceMotion:null});

// --- parseParams：全部參數 ---
eq(A11yCore.parseParams('?mode=problem&off=routeFocus%2CformFeedback&embedded=1&lang=zh-TW&theme=dark&textScale=1.30&bold=1&contrast=0&reduceMotion=1'),
   {mode:'problem', off:['routeFocus','formFeedback'], embedded:true, lang:'zh-TW', theme:'dark', textScale:1.3, bold:true, contrast:false, reduceMotion:true});

// --- parseParams：不合法的值一律當作沒帶 ---
var bad = A11yCore.parseParams('?mode=evil&off=a%3Cb,ok&theme=pink&textScale=abc&lang=%3Cscript%3E');
eq(bad.mode, 'fixed');
eq(bad.off, ['ok']);
eq(bad.theme, null);
eq(bad.textScale, null);
eq(bad.lang, null);

// --- parseParams：字級倍率限制在 0.8–3.0 ---
eq(A11yCore.parseParams('?textScale=9').textScale, 3);
eq(A11yCore.parseParams('?textScale=0.1').textScale, 0.8);

// --- fixEnabled：只有本頁宣告的修正可以被關掉 ---
eq(A11yCore.fixEnabled('textScale', ['textScale'], 'problem', []), false);
eq(A11yCore.fixEnabled('theme', ['textScale'], 'problem', []), true);
eq(A11yCore.fixEnabled('textScale', ['textScale'], 'fixed', []), true);
eq(A11yCore.fixEnabled('routeFocus', ['arrival','routeFocus'], 'fixed', ['routeFocus']), false);
eq(A11yCore.fixEnabled('arrival', ['arrival','routeFocus'], 'fixed', ['routeFocus']), true);
eq(A11yCore.fixEnabled('theme', ['textScale'], 'fixed', ['theme']), true);   // off 只對本頁宣告的修正有效

// --- effectiveTheme ---
eq(A11yCore.effectiveTheme({param:'dark', systemDark:false, honorParam:true}), 'dark');
eq(A11yCore.effectiveTheme({param:'dark', systemDark:false, honorParam:false}), 'light');
eq(A11yCore.effectiveTheme({param:null, systemDark:true, honorParam:true}), 'dark');

// --- rootFontPercent ---
eq(A11yCore.rootFontPercent(1.3, true), 130);
eq(A11yCore.rootFontPercent(1.3, false), 100);
eq(A11yCore.rootFontPercent(null, true), 100);

// --- resolvePref ---
eq(A11yCore.resolvePref({media:false, param:true, honorParam:true}), true);
eq(A11yCore.resolvePref({media:false, param:true, honorParam:false}), false);
eq(A11yCore.resolvePref({media:true, param:null, honorParam:false}), true);

// ===== 以下是實作計畫以外另外加上的斷言：執行期部分用到的其他純函式，以及更多不合法的輸入 =====

// --- parseParams：更多不合法的輸入 ---
var odd = A11yCore.parseParams('?embedded=true&textScale=1e3&bold=2&contrast=&reduceMotion=yes&lang=zh-Hant-TW&off=');
eq(odd.embedded, false);
eq(odd.textScale, null);
eq(odd.bold, null);
eq(odd.contrast, null);
eq(odd.reduceMotion, null);
eq(odd.lang, 'zh-Hant-TW');
eq(odd.off, []);
eq(A11yCore.parseParams('?textScale=-2').textScale, null);
eq(A11yCore.parseParams('?textScale=3.00').textScale, 3);
eq(A11yCore.parseParams('?textScale=0.80').textScale, 0.8);

// --- effectiveTheme、rootFontPercent、resolvePref：補上其餘組合 ---
eq(A11yCore.effectiveTheme({param:'light', systemDark:true, honorParam:true}), 'light');
eq(A11yCore.effectiveTheme({param:'pink', systemDark:true, honorParam:true}), 'dark');
eq(A11yCore.rootFontPercent(9, true), 300);
eq(A11yCore.rootFontPercent(0.1, true), 80);
eq(A11yCore.resolvePref({media:true, param:false, honorParam:true}), true);   // 網頁自己偵測到的優先
eq(A11yCore.resolvePref({media:false, param:null, honorParam:true}), false);

// --- 修正名稱的詞彙，以及 <body data-fixes> 的解析 ---
eq(A11yCore.FIX_NAMES, ['textScale','theme','a11yPrefs','lang','embeddedChrome','embeddedTitle','arrival','routeFocus','back','zoom','dialogReturn','formErrors','formFeedback','safeArea']);
eq(A11yCore.parseFixList('arrival  routeFocus'), ['arrival','routeFocus']);
eq(A11yCore.parseFixList(''), []);
eq(A11yCore.parseFixList(null), []);
eq(A11yCore.parseFixList('textScale bogus <b>'), ['textScale']);   // 不在詞彙裡的名稱不算

// --- enabledFixes：ready 訊息的 caps（全部修正名稱當中目前啟用的，順序固定）---
eq(A11yCore.enabledFixes([], 'problem', []), A11yCore.FIX_NAMES);   // 本頁沒有宣告修正：全部啟用
eq(A11yCore.enabledFixes(['arrival','routeFocus'], 'problem', []),
   ['textScale','theme','a11yPrefs','lang','embeddedChrome','embeddedTitle','back','zoom','dialogReturn','formErrors','formFeedback','safeArea']);
eq(A11yCore.enabledFixes(['arrival','routeFocus'], 'fixed', ['routeFocus']),
   ['textScale','theme','a11yPrefs','lang','embeddedChrome','embeddedTitle','arrival','back','zoom','dialogReturn','formErrors','formFeedback','safeArea']);

// --- normalizeSettings：App 用 updateSettings 傳來的值同樣要過白名單 ---
eq(A11yCore.normalizeSettings({theme:'dark', textScale:1.3}), {theme:'dark', textScale:1.3});
eq(A11yCore.normalizeSettings({lang:'en', bold:true, contrast:false, reduceMotion:true}), {lang:'en', bold:true, contrast:false, reduceMotion:true});
eq(A11yCore.normalizeSettings({theme:'pink', textScale:'big', lang:'<script>', bold:'yes', mode:'problem', off:['theme'], embedded:true}), {});
eq(A11yCore.normalizeSettings({textScale:9}), {textScale:3});
eq(A11yCore.normalizeSettings({textScale:0.1}), {textScale:0.8});
eq(A11yCore.normalizeSettings({textScale:NaN}), {});
eq(A11yCore.normalizeSettings(null), {});
eq(A11yCore.normalizeSettings('theme=dark'), {});

// --- buildSearch：只用驗證過的值重組查詢字串（參數順序與格式和 App 端相同）---
var full = '?mode=problem&off=routeFocus%2CformFeedback&embedded=1&lang=zh-TW&theme=dark&textScale=1.30&bold=1&contrast=0&reduceMotion=1';
eq(A11yCore.buildSearch(A11yCore.parseParams(full)), full);
eq(A11yCore.buildSearch(A11yCore.parseParams('')), '?mode=fixed');
eq(A11yCore.buildSearch(A11yCore.parseParams('?mode=evil&theme=pink&x=%3Cscript%3E&textScale=1.5')), '?mode=fixed&textScale=1.50');
