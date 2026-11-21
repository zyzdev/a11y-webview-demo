// DemoWebViewLogic：已換上／載入中、信任判斷、ready 與 reportReady、設定的重送、字級套用到哪一頁（設計文件 §6.1–§6.3）。
//
// 事件順序照模擬器上量到的時序（Task 5 修正第一輪的報告）：
// - Android：onPageStarted 時新頁面已換上 → onUrlChange → ready → onPageFinished。
// - iOS：點連結時 onPageStarted → onUrlChange 在新頁面換上之前就到（舊頁面仍可能送訊息）；
//   第一次 loadRequest 時 onUrlChange 比 onPageStarted 早好幾秒；
//   換上前取消（204、取消、tel:）時先收到變回原網址的 onUrlChange，再收到錯誤；
//   換上後才停止（window.stop()）時只有錯誤，網址不變回去；
//   bfcache 返回時 ready 可能在 onPageFinished 之前，onUrlChange 可能在 onPageFinished 之後。

import 'package:a11y_webview_demo/contract/web_contract.dart';
import 'package:a11y_webview_demo/webview/demo_webview_config.dart';
import 'package:a11y_webview_demo/webview/demo_webview_logic.dart';
import 'package:flutter_test/flutter_test.dart';

final _base = Uri.parse('http://127.0.0.1:8123/');
const _self = 'http://127.0.0.1:8123/pages/c01-text-scale.html?mode=fixed&embedded=1';
const _selfSlow = 'http://127.0.0.1:8123/pages/c01-text-scale.html?mode=fixed&embedded=1&__delay=7000';
const _selfIndex = 'http://127.0.0.1:8123/index.html';
const _ext = 'http://127.0.0.1:8766/plain.html';
const _evil = 'http://127.0.0.1:8766/evil.html';
const _noContent = 'http://127.0.0.1:8766/nocontent';
const _tel = 'tel:+886212345678';

const _s1 = WebSettingsSnapshot(lang: 'zh-TW', theme: 'light', textScale: 1.0);
const _s2 = WebSettingsSnapshot(lang: 'zh-TW', theme: 'dark', textScale: 1.0);

DemoWebViewLogic _logic({
  TextScaleStrategy strategy = TextScaleStrategy.webOwned,
  WebSettingsSnapshot snapshot = _s1,
  double scale = 1.0,
}) =>
    DemoWebViewLogic(webBase: _base, textScale: strategy, snapshot: snapshot, appTextScale: scale);

/// 第一次載入自家頁面並換上（App 發起 → onPageStarted → ready → onPageFinished）。
DemoWebViewLogic _loadedSelf({
  TextScaleStrategy strategy = TextScaleStrategy.webOwned,
  double scale = 1.0,
}) {
  final l = _logic(strategy: strategy, scale: scale);
  l.appLoadStarted(Uri.parse(_self));
  l.pageStarted(_self);
  l.urlChanged(_self);
  l.readyAccepted();
  l.pageFinished(_self);
  expect(l.committedUrl, Uri.parse(_self));
  expect(l.loading, isFalse);
  expect(l.readyOnCommittedPage, isTrue);
  return l;
}

/// 從自家頁導向 [url] 並換上（沒有收到 ready）。
void _navigateAndFinish(DemoWebViewLogic l, String url) {
  l.pageStarted(url);
  l.urlChanged(url);
  l.pageFinished(url);
}

void main() {
  group('第一次載入', () {
    test('App 發起的載入在呼叫時就記為載入中；還沒換上過任何頁面時只看載入中的網址', () {
      final l = _logic();
      expect(l.acceptsMessages, isFalse, reason: '還沒有任何頁面');
      l.appLoadStarted(Uri.parse(_self));
      expect(l.loading, isTrue);
      expect(l.pendingUrl, Uri.parse(_self));
      expect(l.committedUrl, isNull);
      expect(l.acceptsMessages, isTrue);

      final other = _logic()..appLoadStarted(Uri.parse(_ext));
      expect(other.acceptsMessages, isFalse);
    });

    test('iOS：onUrlChange 比 onPageStarted 早到，仍是載入中；ready 在換上前送設定，換上後不補送、不重送', () {
      final l = _logic();
      l.appLoadStarted(Uri.parse(_self));
      expect(l.urlChanged(_self), isEmpty);
      expect(l.loading, isTrue);
      expect(l.committedUrl, isNull);
      l.pageStarted(_self);
      expect(l.readyAccepted(), [const SendSettings(_s1)]);
      final finished = l.pageFinished(_self);
      expect(finished, isNot(contains(const RequestReportReady())));
      expect(finished.whereType<SendSettings>(), isEmpty);
      expect(l.readyOnCommittedPage, isTrue);
    });

    test('還沒換上過任何頁面時收到 onUrlChange，也當成開始載入', () {
      final l = _logic();
      l.urlChanged(_self);
      expect(l.loading, isTrue);
      expect(l.committedUrl, isNull);
    });
  });

  group('Android 時序（onPageStarted 時已換上）', () {
    test('自家→自家：載入中新頁面的 ready 被接受，換上後不補送', () {
      final l = _loadedSelf();
      l.pageStarted(_selfIndex);
      expect(l.acceptsMessages, isTrue);
      l.urlChanged(_selfIndex);
      expect(l.readyAccepted(), [const SendSettings(_s1)]);
      final finished = l.pageFinished(_selfIndex);
      expect(finished, isNot(contains(const RequestReportReady())));
      expect(finished.whereType<SendSettings>(), isEmpty);
      expect(l.committedUrl, Uri.parse(_selfIndex));
      expect(l.readyOnCommittedPage, isTrue);
    });

    test('外部→自家：載入中新頁面送的 ready 被擋，換上後請網頁補送，補送的 ready 被接受', () {
      final l = _loadedSelf();
      _navigateAndFinish(l, _ext);
      expect(l.committedUrl, Uri.parse(_ext));
      expect(l.acceptsMessages, isFalse);

      l.pageStarted(_self);
      l.urlChanged(_self);
      expect(l.acceptsMessages, isFalse, reason: '已換上的仍是外部頁');
      final finished = l.pageFinished(_self);
      expect(finished, contains(const RequestReportReady()));
      expect(l.acceptsMessages, isTrue);
      expect(l.readyAccepted(), [const SendSettings(_s1)]);
      expect(l.readyOnCommittedPage, isTrue);
    });
  });

  group('iOS 時序（onPageStarted 後舊頁面仍會送訊息，onPageFinished 才換上）', () {
    test('外部頁持續送假 ready 並導向自家慢速頁：載入中全部被擋；載入完成後請網頁補送', () {
      final l = _loadedSelf();
      _navigateAndFinish(l, _evil);
      expect(l.acceptsMessages, isFalse);

      l.pageStarted(_selfSlow);
      l.urlChanged(_selfSlow);
      for (var i = 0; i < 24; i++) {
        expect(l.acceptsMessages, isFalse, reason: '第 ${i + 1} 則假 ready');
      }
      final finished = l.pageFinished(_selfSlow);
      expect(finished, contains(const RequestReportReady()));
      expect(l.acceptsMessages, isTrue);
    });

    test('自家頁導向外部頁的載入中，自家頁送的訊息被擋；204 變回原網址並收到錯誤之後，自家頁的訊息恢復被接受', () {
      final l = _loadedSelf();
      l.pageStarted(_noContent);
      expect(l.acceptsMessages, isFalse);
      l.urlChanged(_noContent);
      expect(l.acceptsMessages, isFalse);
      l.urlChanged(_self); // 變回原網址
      l.mainFrameError(); // 102 頁框載入中斷
      expect(l.loading, isFalse);
      expect(l.committedUrl, Uri.parse(_self));
      expect(l.acceptsMessages, isTrue);
      expect(l.readyOnCommittedPage, isTrue, reason: '沒換成頁的導覽不能重設原本那一頁的 ready 狀態');
      // 之後改設定仍會送給原本那一頁。
      expect(l.settingsChanged(_s2, 1.0), [const SendSettings(_s2)]);
    });

    test('window.stop()：外部頁換上後才停止，網址沒有變回去 → 以外部頁為已換上，訊息被擋，也不送設定', () {
      final l = _loadedSelf();
      l.pageStarted(_ext);
      l.urlChanged(_ext);
      final effects = l.mainFrameError(); // -999
      expect(l.loading, isFalse);
      expect(l.committedUrl, Uri.parse(_ext));
      expect(l.acceptsMessages, isFalse);
      expect(effects, isNot(contains(const RequestReportReady())));
      expect(l.settingsChanged(_s2, 1.0).whereType<SendSettings>(), isEmpty);
    });

    test('取消（載入中再導向別處）：變回原網址、錯誤，接著新的載入照常換上', () {
      final l = _loadedSelf();
      l.pageStarted(_selfSlow);
      l.urlChanged(_selfSlow);
      l.urlChanged(_self);
      l.mainFrameError(); // -999
      expect(l.committedUrl, Uri.parse(_self));
      expect(l.loading, isFalse);
      l.pageStarted(_selfIndex);
      l.urlChanged(_selfIndex);
      l.readyAccepted();
      l.pageFinished(_selfIndex);
      expect(l.committedUrl, Uri.parse(_selfIndex));
      expect(l.readyOnCommittedPage, isTrue);
    });

    test('tel:：變回原網址、錯誤 → 已換上的網址與 ready 狀態不變，載入中結束', () {
      final l = _loadedSelf();
      l.pageStarted(_tel);
      expect(l.acceptsMessages, isFalse);
      l.urlChanged(_tel);
      l.urlChanged(_self);
      l.mainFrameError(); // -1002
      expect(l.loading, isFalse);
      expect(l.committedUrl, Uri.parse(_self));
      expect(l.readyOnCommittedPage, isTrue);
      expect(l.acceptsMessages, isTrue);
    });

    test('錯誤先到、變回原網址的 onUrlChange 後到：中間只會多擋訊息；之後 onUrlChange 換了 origin 會開始載入（fail-closed）', () {
      final l = _loadedSelf();
      l.pageStarted(_noContent);
      l.urlChanged(_noContent);
      l.mainFrameError();
      expect(l.committedUrl, Uri.parse(_noContent));
      expect(l.acceptsMessages, isFalse);
      l.urlChanged(_self);
      expect(l.loading, isTrue);
      expect(l.acceptsMessages, isFalse);
    });

    test('殘留風險（設計文件 §6.3 記下的，不是要的行為）：外部頁導向自家時被取消，錯誤先到、網址變回外部後到 → '
        '中間那一瞬間外部頁的訊息會被當成自家的；變回外部的 onUrlChange 到了之後又被擋', () {
      // 模擬器上量到的順序是「先變回原網址、再錯誤」，這裡是假設某個版本順序相反時的結果。這條測試只是把目前的
      // 行為釘住：之後如果行為改變（例如修掉這個風險），要同時更新設計文件 §6.3 的殘留風險。
      final l = _loadedSelf();
      _navigateAndFinish(l, _evil);
      l.pageStarted(_selfSlow);
      l.urlChanged(_selfSlow);
      expect(l.acceptsMessages, isFalse);
      final effects = l.mainFrameError(); // 錯誤先到：以最後回報的網址（自家）為已換上
      expect(l.committedUrl, Uri.parse(_selfSlow));
      expect(l.acceptsMessages, isTrue, reason: '殘留風險：畫面上其實是外部頁');
      expect(effects, contains(const RequestReportReady()), reason: '殘留風險：補送 ready 的請求會送到畫面上的外部頁');
      l.urlChanged(_evil); // 變回外部的 onUrlChange 後到：換了 origin，照 fail-closed 記為載入中
      expect(l.loading, isTrue);
      expect(l.acceptsMessages, isFalse);
    });

    test('bfcache 返回（ready 在 onPageFinished 之前、onUrlChange 在它之後）：ready 被擋，換上後請網頁補送', () {
      final l = _loadedSelf();
      _navigateAndFinish(l, _ext);
      l.pageStarted(_self);
      expect(l.acceptsMessages, isFalse, reason: '舊頁面（外部）可能還在畫面上');
      final finished = l.pageFinished(_self);
      expect(finished, contains(const RequestReportReady()));
      expect(l.urlChanged(_self), isEmpty);
      expect(l.loading, isFalse, reason: '同一個網址的 onUrlChange 不會開始新的載入');
      expect(l.acceptsMessages, isTrue);
    });
  });

  group('一串載入（載入中又開始新的載入）：先前的載入中網址也列入信任判斷，這一串結束時清掉', () {
    test('iOS：外部頁換上後仍在載入（慢圖片、沒有 onPageFinished）時導向自家慢速頁 → 訊息被擋；'
        '有 onPageStarted 的 onPageFinished 換上自家頁、請網頁補送 ready、恢復接受', () {
      final l = _loadedSelf();
      l.pageStarted(_evil);
      l.urlChanged(_evil);
      expect(l.acceptsMessages, isFalse);
      // 外部頁已換上、畫面上是它，但圖片 20 秒才回應，所以沒有 onPageFinished。3 秒後它導向自家慢速頁。
      l.pageStarted(_selfSlow);
      l.urlChanged(_selfSlow);
      expect(l.committedUrl, Uri.parse(_self), reason: '外部頁沒有 onPageFinished，App 不知道它換上了');
      expect(l.pendingUrl, Uri.parse(_selfSlow));
      for (var i = 0; i < 28; i++) {
        expect(l.acceptsMessages, isFalse, reason: '第 ${i + 1} 則假 ready：先前的載入中網址（外部頁）仍列入判斷');
      }
      final finished = l.pageFinished(_selfSlow);
      expect(l.committedUrl, Uri.parse(_selfSlow));
      expect(finished, contains(const RequestReportReady()));
      expect(l.acceptsMessages, isTrue);
      expect(l.readyAccepted(), [const SendSettings(_s1)]);
      expect(l.readyOnCommittedPage, isTrue);
    });

    test('自家頁仍在載入時再導向另一個自家頁：訊息照常接受', () {
      final l = _loadedSelf();
      l.pageStarted(_selfIndex);
      l.urlChanged(_selfIndex);
      expect(l.acceptsMessages, isTrue);
      l.pageStarted(_selfSlow);
      l.urlChanged(_selfSlow);
      expect(l.acceptsMessages, isTrue);
      expect(l.readyAccepted(), [const SendSettings(_s1)]);
      l.pageFinished(_selfSlow);
      expect(l.committedUrl, Uri.parse(_selfSlow));
      expect(l.readyOnCommittedPage, isTrue);
      expect(l.acceptsMessages, isTrue);
    });

    test('這一串載入以錯誤結束、網址變回外部頁 → 已換上的網址是外部頁、訊息被擋', () {
      final l = _loadedSelf();
      l.pageStarted(_evil);
      l.urlChanged(_evil);
      l.pageStarted(_selfSlow);
      l.urlChanged(_selfSlow);
      expect(l.acceptsMessages, isFalse);
      l.urlChanged(_evil); // 導向自家被取消，網址變回畫面上的外部頁
      final effects = l.mainFrameError(); // -999
      expect(l.loading, isFalse);
      expect(l.committedUrl, Uri.parse(_evil));
      expect(l.acceptsMessages, isFalse);
      expect(effects, isNot(contains(const RequestReportReady())));
    });

    test('這一串載入以錯誤結束、網址變回原本的自家頁 → 先前的載入中網址清掉，恢復接受', () {
      final l = _loadedSelf();
      l.pageStarted(_evil);
      l.urlChanged(_evil);
      l.pageStarted(_selfSlow);
      l.urlChanged(_selfSlow);
      expect(l.acceptsMessages, isFalse);
      l.urlChanged(_self);
      l.mainFrameError();
      expect(l.loading, isFalse);
      expect(l.committedUrl, Uri.parse(_self));
      expect(l.readyOnCommittedPage, isTrue);
      expect(l.acceptsMessages, isTrue);
      // 下一串載入從頭算，不帶著上一串的外部網址。
      l.pageStarted(_selfIndex);
      expect(l.acceptsMessages, isTrue);
    });

    test('App 發起的載入、fail-closed 開始的載入也算先前的載入中網址', () {
      final app = _loadedSelf();
      app.appLoadStarted(Uri.parse(_ext));
      app.pageStarted(_selfSlow);
      app.urlChanged(_selfSlow);
      expect(app.acceptsMessages, isFalse, reason: 'App 發起的載入中網址（外部）');

      final failClosed = _loadedSelf();
      failClosed.urlChanged(_ext); // 換了 origin 的 onUrlChange，記為載入中
      failClosed.pageStarted(_selfSlow);
      failClosed.urlChanged(_selfSlow);
      expect(failClosed.acceptsMessages, isFalse, reason: 'fail-closed 開始的載入中網址（外部）');
      failClosed.pageFinished(_selfSlow);
      expect(failClosed.acceptsMessages, isTrue);
    });
  });

  group('沒有 onPageStarted 的 onPageFinished（Android 的 204、取消導覽）', () {
    const s15 = WebSettingsSnapshot(lang: 'zh-TW', theme: 'light', textScale: 1.5);

    test('Android 導向 204：只收到 onPageFinished → 已換上的網址不變、訊息照常接受、不補送、之後改字級不會把自家頁設成 App 負責的倍率', () {
      final l = _loadedSelf();
      expect(l.pageFinished(_noContent), isEmpty);
      expect(l.committedUrl, Uri.parse(_self));
      expect(l.loading, isFalse);
      expect(l.acceptsMessages, isTrue);
      expect(l.readyOnCommittedPage, isTrue);
      final effects = l.settingsChanged(s15, 1.5);
      expect(effects, [const SendSettings(s15)], reason: '網頁負責：只送設定，Android 維持 setTextZoom(100)');
    });

    test('Android 取消導覽：被取消的那次只有 onPageFinished，接著的載入照常換上', () {
      final l = _loadedSelf();
      expect(l.pageFinished(_selfSlow), isEmpty);
      expect(l.committedUrl, Uri.parse(_self));
      expect(l.readyOnCommittedPage, isTrue);
      l.pageStarted(_selfIndex);
      l.urlChanged(_selfIndex);
      l.readyAccepted();
      l.pageFinished(_selfIndex);
      expect(l.committedUrl, Uri.parse(_selfIndex));
      expect(l.readyOnCommittedPage, isTrue);
    });

    test('App 發起的 loadUri 打到 204：載入中、沒有 onPageStarted、只收到 onPageFinished → 結束載入中、已換上的網址不變、不補送、Android 字級不動',
        () {
      final l = _loadedSelf(scale: 1.5);
      expect(l.appLoadStarted(Uri.parse(_noContent)), isEmpty, reason: 'Android 還沒換上新頁面，不改 setTextZoom');
      expect(l.loading, isTrue);
      expect(l.acceptsMessages, isFalse, reason: '載入中兩個網址都要屬於自家');
      expect(l.settingsChanged(s15, 1.5), isEmpty, reason: '載入中不送');
      final finished = l.pageFinished(_noContent);
      expect(l.loading, isFalse);
      expect(l.committedUrl, Uri.parse(_self));
      expect(l.acceptsMessages, isTrue);
      expect(finished, [const SendSettings(s15)], reason: '只補送載入中被擋下的設定，不補送 ready、不改字級');
    });

    test('換上之後重複收到同一頁的 onPageFinished 不改變狀態', () {
      final l = _loadedSelf();
      expect(l.pageFinished(_self), isEmpty);
      expect(l.readyOnCommittedPage, isTrue);
    });

    // 這次載入中收到過 onUrlChange 時，以最後一次 onUrlChange 的網址為準（和主框架錯誤同一個原則）。
    // 上面三條（Android 的 204、取消導覽，App 發起的 loadUri 打到 204）都沒有 onUrlChange，已換上的網址不變。

    test('fail-closed 開始的載入（換了 origin 的 onUrlChange）只收到 onPageFinished → 換成那個外部網址、訊息被擋；onPageFinished 本身的網址不採用',
        () {
      final l = _loadedSelf(scale: 1.5);
      expect(l.urlChanged(_ext), isEmpty, reason: '還沒有 onPageStarted，Android 的 setTextZoom 跟著已換上的自家頁');
      expect(l.loading, isTrue);
      expect(l.acceptsMessages, isFalse);
      final finished = l.pageFinished(_noContent);
      expect(l.loading, isFalse);
      expect(l.committedUrl, Uri.parse(_ext), reason: '用最後一次 onUrlChange 的網址，不用 onPageFinished 帶的網址');
      expect(l.acceptsMessages, isFalse);
      expect(l.readyOnCommittedPage, isFalse);
      expect(finished, [const SetAndroidTextZoom(150), const SetIosTextSizeAdjust(150)],
          reason: '外部頁改由 App 負責字級；不請外部頁補送 ready、不送設定');
    });

    test('App 發起的載入中收到 onUrlChange、沒有 onPageStarted，只收到 onPageFinished → 以最後一次 onUrlChange 的網址為已換上', () {
      final l = _loadedSelf();
      l.appLoadStarted(Uri.parse(_selfIndex));
      l.urlChanged(_ext);
      l.urlChanged(_evil);
      final finished = l.pageFinished(_noContent);
      expect(l.loading, isFalse);
      expect(l.committedUrl, Uri.parse(_evil));
      expect(l.acceptsMessages, isFalse);
      expect(finished, isNot(contains(const RequestReportReady())));
      expect(finished.whereType<SendSettings>(), isEmpty);
    });

    test('最後一次 onUrlChange 變回已換上的網址，再只收到 onPageFinished → 已換上的網址與 ready 狀態不變', () {
      final l = _loadedSelf();
      l.appLoadStarted(Uri.parse(_ext));
      l.urlChanged(_ext);
      l.urlChanged(_self);
      expect(l.pageFinished(_noContent), isEmpty);
      expect(l.loading, isFalse);
      expect(l.committedUrl, Uri.parse(_self));
      expect(l.readyOnCommittedPage, isTrue);
      expect(l.acceptsMessages, isTrue);
    });
  });

  group('其他網址變化', () {
    test('轉址：載入中的 onUrlChange 更新載入中的網址，換上時以它為準', () {
      final l = _loadedSelf();
      l.pageStarted(_selfIndex);
      l.urlChanged(_ext);
      expect(l.pendingUrl, Uri.parse(_ext));
      expect(l.acceptsMessages, isFalse);
      l.pageFinished('');
      expect(l.committedUrl, Uri.parse(_ext), reason: 'onPageFinished 沒帶網址時用載入中的網址');
    });

    test('網頁內換頁（pushState、錨點）：沒有載入中時直接更新已換上的網址，ready 狀態不變', () {
      final l = _loadedSelf();
      l.urlChanged('http://127.0.0.1:8123/pages/c01-text-scale.html?pushed=1');
      l.urlChanged('http://127.0.0.1:8123/pages/c01-text-scale.html?pushed=1#h2');
      expect(l.loading, isFalse);
      expect(l.committedUrl.toString(), 'http://127.0.0.1:8123/pages/c01-text-scale.html?pushed=1#h2');
      expect(l.readyOnCommittedPage, isTrue);
      expect(l.acceptsMessages, isTrue);
    });

    test('沒有載入中時，scheme、host 或埠不同的 onUrlChange 視為開始載入（fail-closed）', () {
      for (final url in [
        _ext, // 埠不同
        'http://localhost:8123/pages/c01-text-scale.html', // host 不同
        'https://127.0.0.1:8123/pages/c01-text-scale.html', // scheme 不同
        'about:blank',
        null,
      ]) {
        final l = _loadedSelf();
        l.urlChanged(url);
        expect(l.loading, isTrue, reason: '$url');
        expect(l.committedUrl, Uri.parse(_self), reason: '$url');
        expect(l.acceptsMessages, isFalse, reason: '$url');
      }
    });

    test('重新載入：記為載入中，載入中的網址是目前已換上的網址；這次載入沒收到 ready 就請網頁補送', () {
      final l = _loadedSelf();
      l.appLoadStarted(null);
      expect(l.loading, isTrue);
      expect(l.pendingUrl, Uri.parse(_self));
      expect(l.acceptsMessages, isTrue);
      l.pageStarted(_self);
      expect(l.pageFinished(_self), contains(const RequestReportReady()));
    });

    test('沒有載入中時的錯誤回呼不改變狀態', () {
      final l = _loadedSelf();
      expect(l.mainFrameError(), isEmpty);
      expect(l.committedUrl, Uri.parse(_self));
      expect(l.readyOnCommittedPage, isTrue);
    });
  });

  group('設定的重送', () {
    test('ready 之前不送；ready 後送一次；換上後設定改變再送；沒變不送', () {
      final l = _logic();
      l.appLoadStarted(Uri.parse(_self));
      l.pageStarted(_self);
      expect(l.settingsChanged(_s2, 1.0), isEmpty, reason: '還沒收到 ready');
      expect(l.readyAccepted(), [const SendSettings(_s2)]);
      l.pageFinished(_self);
      expect(l.settingsChanged(_s1, 1.0), [const SendSettings(_s1)]);
      expect(l.settingsChanged(_s1, 1.0), isEmpty);
    });

    test('載入中的設定改變等換上後補送給已送過 ready 的頁面', () {
      final l = _loadedSelf();
      l.pageStarted(_selfIndex);
      l.readyAccepted();
      expect(l.settingsChanged(_s2, 1.0), isEmpty, reason: '載入中不送');
      expect(l.pageFinished(_selfIndex), contains(const SendSettings(_s2)));
    });

    test('已換上的頁面不屬於自家網域時不送', () {
      final l = _loadedSelf();
      _navigateAndFinish(l, _ext);
      expect(l.settingsChanged(_s2, 1.0), isEmpty);
    });
  });

  group('字級：什麼時候、對哪一頁、做什麼', () {
    test('網頁負責＋自家頁：App 發起載入時 Android setTextZoom(100)；載入完成時 iOS 清掉 text-size-adjust', () {
      final l = _logic(scale: 1.5);
      expect(l.appLoadStarted(Uri.parse(_self)), [const SetAndroidTextZoom(100)]);
      expect(l.pageStarted(_self), isEmpty);
      final finished = l.pageFinished(_self);
      expect(finished, contains(const ClearIosTextSizeAdjust()));
      expect(finished.whereType<SetIosTextSizeAdjust>(), isEmpty);
    });

    test('網頁負責＋導向外部頁：載入中不注入 iOS（還在畫面上的自家頁不會被放大兩次），外部頁換上後才注入', () {
      final l = _loadedSelf(scale: 1.5);
      expect(l.pageStarted(_ext), [const SetAndroidTextZoom(150)], reason: 'Android 在 onPageStarted 時已換上外部頁');
      expect(l.urlChanged(_ext), isEmpty);
      expect(l.pageFinished(_ext), [const SetIosTextSizeAdjust(150)]);
    });

    test('從外部頁返回自家頁（bfcache）：Android 回到 100，iOS 在換上後清掉', () {
      final l = _loadedSelf(scale: 1.5);
      _navigateAndFinish(l, _ext);
      expect(l.pageStarted(_self), [const SetAndroidTextZoom(100)]);
      final finished = l.pageFinished(_self);
      expect(finished, contains(const ClearIosTextSizeAdjust()));
      expect(finished.whereType<SetIosTextSizeAdjust>(), isEmpty);
    });

    test('204：整個過程都不對自家頁注入；Android 跟著載入中的網址，變回原網址後回到 100', () {
      final l = _loadedSelf(scale: 1.5);
      final all = [
        ...l.pageStarted(_noContent),
        ...l.urlChanged(_noContent),
        ...l.urlChanged(_self),
        ...l.mainFrameError(),
      ];
      expect(all, [const SetAndroidTextZoom(150), const SetAndroidTextZoom(100)]);
      expect(all.whereType<SetIosTextSizeAdjust>(), isEmpty);
    });

    test('window.stop()：外部頁成為已換上時才注入', () {
      final l = _loadedSelf(scale: 1.5);
      l.pageStarted(_ext);
      l.urlChanged(_ext);
      expect(l.mainFrameError(), [const SetIosTextSizeAdjust(150)]);
    });

    test('App 負責：字級改變時重做；載入中不注入，換上時用新的倍率', () {
      final l = _logic(strategy: TextScaleStrategy.appOwned);
      expect(l.appLoadStarted(Uri.parse(_self)), [const SetAndroidTextZoom(100)]);
      expect(l.pageStarted(_self), isEmpty);
      expect(l.pageFinished(_self), [const SetIosTextSizeAdjust(100), const RequestReportReady()]);
      expect(l.settingsChanged(_s1, 1.5), [const SetAndroidTextZoom(150), const SetIosTextSizeAdjust(150)]);
      l.pageStarted(_selfIndex);
      expect(l.settingsChanged(_s1, 2.0), [const SetAndroidTextZoom(200)], reason: '載入中只改 Android');
      expect(l.pageFinished(_selfIndex), [const SetIosTextSizeAdjust(200), const RequestReportReady()]);
    });

    test('網頁負責的字級改變：Android 維持 100、iOS 不動，只把新的設定送給網頁', () {
      final l = _loadedSelf();
      const bigger = WebSettingsSnapshot(lang: 'zh-TW', theme: 'light', textScale: 1.5);
      expect(l.settingsChanged(bigger, 1.5), [const SendSettings(bigger)]);
    });

    test('都不做：任何網址、任何時間點都不動字級', () {
      final l = _logic(strategy: TextScaleStrategy.none, scale: 1.5);
      final all = [
        ...l.appLoadStarted(Uri.parse(_self)),
        ...l.pageStarted(_self),
        ...l.pageFinished(_self),
        ...l.pageStarted(_ext),
        ...l.pageFinished(_ext),
        ...l.settingsChanged(_s1, 2.0),
      ];
      expect(all.where((e) => e is SetAndroidTextZoom || e is SetIosTextSizeAdjust || e is ClearIosTextSizeAdjust), isEmpty);
    });
  });

  group('textScaleActionFor：各策略在兩個平台要做的事（§6.1）', () {
    test('都不做：兩個平台都不動', () {
      expect(textScaleActionFor(TextScaleStrategy.none, 1.5), const TextScaleAction());
    });
    test('網頁負責：Android setTextZoom(100)，iOS 清掉 text-size-adjust', () {
      expect(
        textScaleActionFor(TextScaleStrategy.webOwned, 1.5),
        const TextScaleAction(androidTextZoom: 100, clearIosTextSizeAdjust: true),
      );
    });
    test('App 負責：兩個平台都是倍率×100', () {
      expect(
        textScaleActionFor(TextScaleStrategy.appOwned, 1.5),
        const TextScaleAction(androidTextZoom: 150, iosTextSizeAdjust: 150),
      );
      expect(
        textScaleActionFor(TextScaleStrategy.appOwned, 1.15),
        const TextScaleAction(androidTextZoom: 115, iosTextSizeAdjust: 115),
      );
    });
  });
}
