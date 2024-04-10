import 'dart:js_interop' as js;
import 'dart:js_interop_unsafe';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'package:rich_clipboard_platform_interface/rich_clipboard_platform_interface.dart';
import 'package:web/web.dart';

const _kMimeTextPlain = 'text/plain';
const _kMimeTextHtml = 'text/html';

bool _detectClipboardApi() {
  final clipboard = window.navigator.clipboard;
  for (final methodName in ['read', 'write']) {
    final method = clipboard.getProperty(methodName.toJS);
    if (method == null) {
      return false;
    }
  }

  return true;
}

/// The web implementation of [RichClipboard].
class RichClipboardWeb extends RichClipboardPlatform {
  /// Registers the implementation.
  static void registerWith(Registrar registrar) {
    if (!_detectClipboardApi()) {
      return;
    }
    RichClipboardPlatform.instance = RichClipboardWeb();
  }

  @override
  Future<List<String>> getAvailableTypes() async {
    final clipboard = window.navigator.clipboard as _Clipboard?;
    if (clipboard == null) {
      return [];
    }

    final data = await clipboard.read();
    if (data.isEmpty) {
      return [];
    }
    return data.first.types;
  }

  @override
  Future<RichClipboardData> getData() async {
    final clipboard = window.navigator.clipboard as _Clipboard?;
    if (clipboard == null) {
      return const RichClipboardData();
    }

    final contents = await clipboard.read();
    if (contents.isEmpty) {
      return const RichClipboardData();
    }

    final item = contents.first;
    final availableTypes = item.types;

    String? text;
    String? html;
    if (availableTypes.contains(_kMimeTextPlain)) {
      final textBlob = await item.getType('text/plain');
      text = (await textBlob.text().toDart).toDart;
    }
    if (availableTypes.contains(_kMimeTextHtml)) {
      final htmlBlob = await item.getType('text/html');
      html = (await htmlBlob.text().toDart).toDart;
    }

    return RichClipboardData(
      text: text,
      html: html,
    );
  }

  @override
  Future<void> setData(RichClipboardData data) async {
    final clipboard = window.navigator.clipboard as _Clipboard?;
    if (clipboard == null) {
      return;
    }

    final dataMap = Map.fromEntries(
      data.toMap().entries.where((entry) => entry.value != null).map(
            (entry) => MapEntry(
              entry.key,
              // Wrapping the string in a list here satisfies the Blob
              // constructor and works just fine. If something in Dart or the
              // web APIs change to require a list of individual characters in
              // the future, use the .characters getter from the characters
              // package to safely split the string into unicode grapheme
              // clusters.

              Blob(
                [entry.value!.toJS].toJS,
                BlobPropertyBag(type: entry.key),
              ),
            ),
          ),
    );

    final items = <_ClipboardItem>[
      if (dataMap.isNotEmpty) _ClipboardItem(dataMap.jsify())
    ];
    await clipboard.write(items);
  }
}

@js.JS('Blob')
@js.staticInterop
extension _BlobText on Blob {
  @js.JS('text')
  external js.JSPromise<js.JSString> _text();
  Future<String> text() async => (await _text().toDart).toDart;
}

@js.JS('ClipboardItem')
@js.staticInterop
class _ClipboardItem {
  external factory _ClipboardItem(js.JSAny? args);
}

extension _ClipboardItemImpl on _ClipboardItem {
  @js.JS('getType')
  external js.JSPromise<Blob> _getType(String mimeType);
  Future<Blob> getType(String mimeType) => _getType(mimeType).toDart;

  @js.JS('types')
  external js.JSArray<js.JSString> get _types;
  List<String> get types =>
      _types.toDart.map((j) => j.toDart).toList(growable: false);
}

@js.JS('Clipboard')
@js.staticInterop
class _Clipboard {}

extension _ClipboardImpl on _Clipboard {
  @js.JS('read')
  external js.JSPromise<js.JSArray> _read();
  Future<List<_ClipboardItem>> read() async {
    var result = await _read().toDart;
    return result.toDart.cast<_ClipboardItem>();
  }

  @js.JS('write')
  external js.JSPromise _write(js.JSArray items);
  Future<void> write(List<_ClipboardItem> items) {
    return _write(items.cast<js.JSAny>().toJS).toDart;
  }
}
