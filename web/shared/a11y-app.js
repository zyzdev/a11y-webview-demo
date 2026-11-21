/*
 * a11y-app.js：「App 與網頁的約定」的網頁端實作（約定版本 1）。
 * 約定內容見設計文件 §6（docs/superpowers/specs/2026-11-21-webview-a11y-demo-design.md）。
 *
 * 這個檔案分兩部分：
 *   1. A11yCore：純函式，不碰 DOM。Node 和瀏覽器都能載入，由 test/tests.js 測試。
 *   2. window.a11yApp：執行期部分，只在有 document 時執行。
 *
 * ───────────────────────────────────────────────────────────────────────────
 * 頁面骨架約定（每個示範頁都照這個寫；範本是 pages/b-content.html）
 * ───────────────────────────────────────────────────────────────────────────
 *
 *   <!doctype html>
 *   <html lang="zh-TW">                          ← 一定要有 lang，ready 訊息會回報它
 *   <head>
 *     <meta charset="utf-8">
 *     <meta name="viewport" content="width=device-width, initial-scale=1">
 *     <meta name="color-scheme" content="light dark">
 *     <title>頁面標題</title>                     ← 和 <h1> 同一段文字；App 的 AppBar 顯示的就是它
 *     <link rel="stylesheet" href="../shared/base.css">
 *   </head>
 *   <body data-page="頁面代號" data-fixes="本頁示範的修正名稱">
 *     <script src="../shared/a11y-app.js"></script>
 *     <header class="site-header">
 *       <p class="site-name">WebView 無障礙範例網站</p>
 *       <a class="site-back" href="../index.html">回上一頁</a>
 *       <h1>頁面標題</h1>
 *     </header>
 *     <main>…內容從 <h2> 開始…</main>
 *     <script>…這一頁自己的程式…</script>
 *   </body>
 *   </html>
 *
 * - <head>：上面五項都要有，不載入任何外部資源（要能離線）。viewport 不可以關掉縮放
 *   （只有示範縮放的那一頁會為了問題版去改它）。
 * - <body data-fixes>：用空白分隔的修正名稱，只能用下面「修正名稱」列出的詞彙；
 *   這一頁沒有要示範的網頁端修正就寫 data-fixes=""。
 * - 本檔的 <script> 放在 <body> 的最前面，不加 defer 或 async。這個位置讀得到 <body> 的 data-fixes，
 *   又排在所有內容之前，主題、字級和 header 的顯示在內容出現前就決定好，報讀器不會先讀到之後才被隱藏的
 *   header。
 * - header 的靜態內容（網站名稱、<h1>、回上一頁連結）寫在各頁的 HTML 裡，class 名稱照上面寫。
 *   在 App 內要隱藏哪些部分由 base.css 依 <html> 上的 data-embedded 和 nofix-* 決定。
 *   本檔只產生取決於網址的部分：不在 App 內、而且這一頁有宣告修正時，在 header 最後加上
 *   <nav class="mode-switch">（問題版／修正版切換連結）。
 * - 基準（修正 A）在 App 內會隱藏整個 header，所以 <main> 的內容從 <h2> 開始。
 * - 這一頁自己的 <script> 放在 </body> 之前，可以直接用 window.a11yApp 和 A11yCore。
 *   在這裡註冊的處理函式會趕在 ready 訊息送出（DOMContentLoaded）之前就緒。
 *
 * 本檔在 <html> 上設定的狀態（樣式和各頁的程式都以這些為準）
 *   data-mode="problem|fixed"、data-theme="light|dark"、data-embedded="1|0"
 *   class="nofix-<修正名稱>"：這一頁宣告的修正當中被關掉的，每個一個
 *   class="pref-bold"、"pref-contrast"、"pref-reduce-motion"
 *   style="font-size: <百分比>%"：根字級
 *
 * 修正名稱（data-fixes、off 參數、ready 訊息 caps 共用的詞彙）
 *   由本檔處理：textScale（根字級）、theme（data-theme）、a11yPrefs（pref-* class）、
 *              embeddedChrome 與 embeddedTitle（搭配 base.css 隱藏 header）、arrival（自動送 ready）
 *   由各頁處理：lang、routeFocus、back、zoom、dialogReturn、formErrors、formFeedback、safeArea
 *              （用 a11yApp.fixEnabled('名稱') 或 CSS 的 html.nofix-名稱 判斷）
 *   規則：只有這一頁 data-fixes 列出的修正可以被關掉。mode=problem 關掉列出的全部，off 關掉其中指定的。
 *        沒列在這一頁的修正永遠啟用（基準原則，設計文件 §5.2）。
 *
 * 對 App 送訊息的函式（reportRoute、setBackState、requestClose、postToApp）本身不看修正開關，
 * 要不要呼叫由各頁用 a11yApp.fixEnabled() 決定。唯一的例外是 ready：arrival 啟用時本檔自動送。
 *
 * 朗讀的分工（設計文件 §6.4：一件事只用一種方式讓使用者知道）
 *   網頁內換畫面時，各頁這樣寫：
 *     document.title = 新標題;
 *     if (a11yApp.fixEnabled('arrival')) a11yApp.reportRoute(新標題, 路徑);
 *     if (a11yApp.fixEnabled('routeFocus')) 新畫面的標題.focus();   // 標題要有 tabindex="-1"
 *   reportRoute 在 App 內只送訊息，要不要朗讀由 App 決定，網頁不另外朗讀。
 *   不在 App 內時沒有 App 可以朗讀，才改寫進頁面上隱藏的 aria-live 區域；
 *   但 routeFocus 啟用時焦點落點本身就會被念出來，所以這時也不寫，避免同一個標題被念兩次。
 *
 * a11yApp.params 一開始是 parseParams(location.search) 的結果；App 之後呼叫 updateSettings 時，
 * 其中的設定欄位（lang、theme、textScale、bold、contrast、reduceMotion）會更新成最新的值。
 */

var A11yCore = (function () {
  'use strict';

  var CONTRACT_VERSION = 1;

  // 修正名稱的詞彙，順序固定（ready 訊息的 caps 也照這個順序）。
  var FIX_NAMES = [
    'textScale', 'theme', 'a11yPrefs', 'lang', 'embeddedChrome', 'embeddedTitle', 'arrival',
    'routeFocus', 'back', 'zoom', 'dialogReturn', 'formErrors', 'formFeedback', 'safeArea'
  ];
  var FLAG_NAMES = ['bold', 'contrast', 'reduceMotion'];

  // 白名單格式。網址參數是外來的資料，不符合格式的一律當作沒帶。
  var LANG_PATTERN = /^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$/;
  var FIX_NAME_PATTERN = /^[A-Za-z]+$/;
  var DECIMAL_PATTERN = /^\d+(\.\d+)?$/;

  var TEXT_SCALE_MIN = 0.8;
  var TEXT_SCALE_MAX = 3;

  function clampTextScale(value) {
    return Math.min(TEXT_SCALE_MAX, Math.max(TEXT_SCALE_MIN, value));
  }

  function parseFlag(raw) {
    if (raw === '1') return true;
    if (raw === '0') return false;
    return null;
  }

  // 解析 App 帶在網址上的參數（設計文件 §6.1）。回傳的每個值都已通過白名單驗證。
  function parseParams(search) {
    var query = new URLSearchParams(typeof search === 'string' ? search : '');
    var lang = query.get('lang');
    var theme = query.get('theme');
    var textScale = query.get('textScale');
    return {
      mode: query.get('mode') === 'problem' ? 'problem' : 'fixed',
      off: (query.get('off') || '').split(',').filter(function (name) {
        return FIX_NAME_PATTERN.test(name);
      }),
      embedded: query.get('embedded') === '1',
      lang: lang !== null && LANG_PATTERN.test(lang) ? lang : null,
      theme: theme === 'light' || theme === 'dark' ? theme : null,
      textScale: textScale !== null && DECIMAL_PATTERN.test(textScale)
        ? clampTextScale(parseFloat(textScale))
        : null,
      bold: parseFlag(query.get('bold')),
      contrast: parseFlag(query.get('contrast')),
      reduceMotion: parseFlag(query.get('reduceMotion'))
    };
  }

  // 用 parseParams 驗證過的值重組查詢字串。參數順序與格式和 App 端組網址時相同。
  // 頁面上的連結要帶參數時用這個，不要把 location.search 原樣寫回頁面。
  function buildSearch(params) {
    var parts = ['mode=' + (params.mode === 'problem' ? 'problem' : 'fixed')];
    if (params.off && params.off.length > 0) parts.push('off=' + encodeURIComponent(params.off.join(',')));
    if (params.embedded) parts.push('embedded=1');
    if (params.lang !== null) parts.push('lang=' + encodeURIComponent(params.lang));
    if (params.theme !== null) parts.push('theme=' + params.theme);
    if (params.textScale !== null) parts.push('textScale=' + params.textScale.toFixed(2));
    FLAG_NAMES.forEach(function (name) {
      if (params[name] !== null) parts.push(name + '=' + (params[name] ? '1' : '0'));
    });
    return '?' + parts.join('&');
  }

  // App 用 updateSettings 傳來的設定（JSON 型別：字串、數字、布林）。
  // 只留下合法的欄位，其餘丟掉；和網址參數用同一套白名單。
  function normalizeSettings(input) {
    var settings = {};
    if (typeof input !== 'object' || input === null) return settings;
    if (typeof input.lang === 'string' && LANG_PATTERN.test(input.lang)) settings.lang = input.lang;
    if (input.theme === 'light' || input.theme === 'dark') settings.theme = input.theme;
    if (typeof input.textScale === 'number' && isFinite(input.textScale) && input.textScale >= 0) {
      settings.textScale = clampTextScale(input.textScale);
    }
    FLAG_NAMES.forEach(function (name) {
      if (typeof input[name] === 'boolean') settings[name] = input[name];
    });
    return settings;
  }

  // 解析 <body data-fixes>：空白分隔，只留下詞彙裡有的名稱。
  function parseFixList(raw) {
    return (typeof raw === 'string' ? raw : '').split(/\s+/).filter(function (name) {
      return FIX_NAMES.indexOf(name) !== -1;
    });
  }

  // 基準原則（設計文件 §5.2）：只有本頁宣告（data-fixes）的修正可以被關掉。
  // mode=problem 關掉本頁宣告的全部修正；off 只關掉其中指定的。
  // 不是本頁宣告的修正永遠啟用，這樣每一頁的問題版只會少掉它自己要示範的那一項。
  function fixEnabled(name, pageFixes, mode, off) {
    if ((pageFixes || []).indexOf(name) === -1) return true;
    if (mode === 'problem') return false;
    return (off || []).indexOf(name) === -1;
  }

  // 全部修正名稱當中目前啟用的那些，也就是 ready 訊息的 caps。
  function enabledFixes(pageFixes, mode, off) {
    return FIX_NAMES.filter(function (name) {
      return fixEnabled(name, pageFixes, mode, off);
    });
  }

  // honorParam 為 true（theme 修正啟用）時，App 傳來的主題優先；否則只看系統的深淺色。
  function effectiveTheme(input) {
    if (input.honorParam && (input.param === 'light' || input.param === 'dark')) return input.param;
    return input.systemDark ? 'dark' : 'light';
  }

  // 「網頁負責字級」策略：根字級 = 100% × App 的字級倍率，版面全部用 rem。
  function rootFontPercent(textScale, honor) {
    if (!honor || typeof textScale !== 'number' || !isFinite(textScale)) return 100;
    return Math.round(clampTextScale(textScale) * 100);
  }

  // 粗體、高對比、減少動態：網頁自己偵測得到（media）就以偵測到的為準；
  // 偵測不到時，honorParam 為 true（a11yPrefs 修正啟用）才採用 App 傳來的值。
  function resolvePref(input) {
    if (input.media === true) return true;
    return input.honorParam === true && input.param === true;
  }

  return {
    CONTRACT_VERSION: CONTRACT_VERSION,
    FIX_NAMES: FIX_NAMES.slice(),
    parseParams: parseParams,
    buildSearch: buildSearch,
    normalizeSettings: normalizeSettings,
    parseFixList: parseFixList,
    fixEnabled: fixEnabled,
    enabledFixes: enabledFixes,
    effectiveTheme: effectiveTheme,
    rootFontPercent: rootFontPercent,
    resolvePref: resolvePref
  };
})();

if (typeof document !== 'undefined') {
  (function () {
    'use strict';

    var root = document.documentElement;
    var params = A11yCore.parseParams(window.location.search);

    var backHandler = null;
    var dialogHandler = null;
    var submitHandler = null;
    var settingsListeners = [];
    var routeStatus = null;

    function pageFixes() {
      return document.body ? A11yCore.parseFixList(document.body.getAttribute('data-fixes')) : [];
    }

    function fixEnabled(name) {
      return A11yCore.fixEnabled(name, pageFixes(), params.mode, params.off);
    }

    // 系統設定在頁面開著時改變，就重新套用一次。
    function watchMedia(query) {
      var list = typeof window.matchMedia === 'function' ? window.matchMedia(query) : null;
      if (!list) return { matches: false };
      if (list.addEventListener) list.addEventListener('change', applySettings);
      else if (list.addListener) list.addListener(applySettings);   // iOS 13 只有舊的 addListener
      return list;
    }

    var systemDark = watchMedia('(prefers-color-scheme: dark)');
    var systemContrast = watchMedia('(prefers-contrast: more)');
    var systemReduceMotion = watchMedia('(prefers-reduced-motion: reduce)');

    // 會隨 updateSettings 和系統設定改變的部分：主題、根字級、偏好。
    function applySettings() {
      root.setAttribute('data-theme', A11yCore.effectiveTheme({
        param: params.theme,
        systemDark: systemDark.matches,
        honorParam: fixEnabled('theme')
      }));
      root.style.fontSize = A11yCore.rootFontPercent(params.textScale, fixEnabled('textScale')) + '%';

      var honorPrefs = fixEnabled('a11yPrefs');
      // 粗體文字沒有對應的 media query，只有 App 知道。
      root.classList.toggle('pref-bold', A11yCore.resolvePref({
        media: false, param: params.bold, honorParam: honorPrefs
      }));
      root.classList.toggle('pref-contrast', A11yCore.resolvePref({
        media: systemContrast.matches, param: params.contrast, honorParam: honorPrefs
      }));
      root.classList.toggle('pref-reduce-motion', A11yCore.resolvePref({
        media: systemReduceMotion.matches, param: params.reduceMotion, honorParam: honorPrefs
      }));
    }

    // 載入後就不變的部分，加上第一次套用設定。
    function applyPageState() {
      root.setAttribute('data-mode', params.mode);
      root.setAttribute('data-embedded', params.embedded ? '1' : '0');
      pageFixes().forEach(function (name) {
        root.classList.toggle('nofix-' + name, !fixEnabled(name));
      });
      applySettings();
    }

    function callSafely(fn, args) {
      if (typeof fn !== 'function') return;
      // App 是用 runJavaScript 呼叫進來的；頁面的處理函式出錯不該變成 App 那一端的例外。
      try {
        fn.apply(null, args || []);
      } catch (error) {
        if (window.console) window.console.error('[a11yApp]', error);
      }
    }

    // 網頁 → App（設計文件 §6.3）。A11yBridge 不存在（一般瀏覽器、In-app browser）時靜默略過。
    // 回傳有沒有送出去。
    function postToApp(message) {
      var bridge = window.A11yBridge;
      if (!bridge || typeof bridge.postMessage !== 'function') return false;
      try {
        bridge.postMessage(JSON.stringify(message));
        return true;
      } catch (error) {
        return false;
      }
    }

    function reportReady() {
      var message = { type: 'ready', title: document.title };
      if (root.lang) message.lang = root.lang;
      message.contract = A11yCore.CONTRACT_VERSION;
      message.caps = A11yCore.enabledFixes(pageFixes(), params.mode, params.off);
      return postToApp(message);
    }

    // 不在 App 內時用來念出新畫面標題的隱藏區域。要在內容改變之前就存在，報讀器才會念。
    function ensureRouteStatus() {
      if (!routeStatus && document.body) {
        routeStatus = document.createElement('div');
        routeStatus.id = 'a11y-route-status';
        routeStatus.className = 'visually-hidden';
        routeStatus.setAttribute('aria-live', 'polite');
        document.body.appendChild(routeStatus);
      }
      return routeStatus;
    }

    // 網頁內換畫面。朗讀的分工見檔頭：一件事只用一種方式讓使用者知道。
    function reportRoute(title, path) {
      var text = title == null ? '' : String(title);
      if (params.embedded) {
        // 在 App 內：只送訊息。App 安靜地更新 AppBar 標題，要不要朗讀由 App 決定。
        postToApp({
          type: 'routeChanged',
          title: text,
          path: path == null ? window.location.pathname : String(path)
        });
        return;
      }
      // 不在 App 內：routeFocus 啟用時焦點會移到新標題，由焦點落點被念出來，這裡不再重複。
      if (fixEnabled('routeFocus')) return;
      var region = ensureRouteStatus();
      if (region) region.textContent = text;
    }

    function setBackState(canHandleBack) {
      return postToApp({ type: 'backState', canHandleBack: !!canHandleBack });
    }

    function requestClose() {
      return postToApp({ type: 'close' });
    }

    // App → 網頁（設計文件 §6.2）。值先過白名單，不合法的欄位維持原值。
    function updateSettings(settings) {
      var valid = A11yCore.normalizeSettings(settings);
      Object.keys(valid).forEach(function (key) {
        params[key] = valid[key];
      });
      applySettings();
      settingsListeners.slice().forEach(function (listener) {
        callSafely(listener, [params]);
      });
    }

    function modeSearch(mode) {
      var copy = {};
      Object.keys(params).forEach(function (key) {
        copy[key] = params[key];
      });
      copy.mode = mode;
      copy.off = [];
      return A11yCore.buildSearch(copy);
    }

    // 不在 App 內時，讓人可以直接在瀏覽器切換問題版和修正版。
    // 這一頁沒有宣告修正的話兩版完全一樣，就不顯示。
    function addModeSwitch() {
      var header = document.querySelector('.site-header');
      var fixes = pageFixes();
      if (!header || params.embedded || fixes.length === 0) return;

      var allEnabled = fixes.every(fixEnabled);
      var nav = document.createElement('nav');
      nav.className = 'mode-switch';
      nav.setAttribute('aria-label', '版本切換');
      [['problem', '問題版'], ['fixed', '修正版']].forEach(function (item) {
        var link = document.createElement('a');
        link.href = modeSearch(item[0]);
        link.textContent = item[1];
        // 用 off 只關掉一部分修正時，兩個都不是目前的版本。
        var current = item[0] === 'problem' ? params.mode === 'problem' : allEnabled;
        if (current) link.setAttribute('aria-current', 'true');
        nav.appendChild(link);
      });
      header.appendChild(nav);
    }

    function warnUnknownFixes() {
      var declared = (document.body.getAttribute('data-fixes') || '').split(/\s+/).filter(Boolean);
      var unknown = declared.filter(function (name) {
        return A11yCore.FIX_NAMES.indexOf(name) === -1;
      });
      if (unknown.length > 0 && window.console) {
        window.console.warn('[a11yApp] data-fixes 裡有不在約定詞彙內的名稱，已忽略：' + unknown.join('、'));
      }
    }

    function onDomReady() {
      applyPageState();   // 本檔若被放在 <head>，這時才讀得到 <body data-fixes>
      warnUnknownFixes();
      addModeSwitch();
      if (!params.embedded) ensureRouteStatus();
      if (fixEnabled('arrival')) reportReady();
    }

    window.a11yApp = {
      params: params,
      fixEnabled: fixEnabled,
      postToApp: postToApp,
      reportReady: reportReady,
      reportRoute: reportRoute,
      setBackState: setBackState,
      requestClose: requestClose,
      updateSettings: updateSettings,
      onSettingsChanged: function (listener) {
        if (typeof listener === 'function') settingsListeners.push(listener);
      },
      setBackHandler: function (fn) { backHandler = fn; },
      handleBack: function () { callSafely(backHandler); },
      setDialogHandler: function (fn) { dialogHandler = fn; },
      onNativeDialogClosed: function (requestId, action) { callSafely(dialogHandler, [requestId, action]); },
      setSubmitHandler: function (fn) { submitHandler = fn; },
      submitForm: function () { callSafely(submitHandler); }
    };

    applyPageState();

    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', onDomReady);
    } else {
      onDomReady();
    }

    // 從 bfcache 回來時不會再觸發 DOMContentLoaded，App 那邊卻已經換過頁，所以要再報一次。
    window.addEventListener('pageshow', function (event) {
      if (event.persisted && fixEnabled('arrival')) reportReady();
    });
  })();
}

if (typeof module !== 'undefined') module.exports = { A11yCore: A11yCore };
