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
    final clipboard = window.navigator.clipboard as Clipboard?;
    if (clipboard == null) {
      return [];
    }

    final data = (await clipboard.read().toDart).toDart;
    if (data.isEmpty) {
      return [];
    }
    return data.first.types.toDart.map((item) => item.toDart).toList();
  }

  @override
  Future<RichClipboardData> getData() async {
    final clipboard = window.navigator.clipboard as Clipboard?;
    if (clipboard == null) {
      return const RichClipboardData();
    }

    final contents = (await clipboard.read().toDart).toDart;
    if (contents.isEmpty) {
      return const RichClipboardData();
    }

    final item = contents.first;
    final availableTypes = item.types.toDart;

    String? text;
    String? html;
    if (availableTypes.contains(_kMimeTextPlain)) {
      final textBlob = await item.getType('text/plain').toDart;
      text = (await textBlob.text().toDart).toDart;
    }
    if (availableTypes.contains(_kMimeTextHtml)) {
      final htmlBlob = await item.getType('text/html').toDart;
      html = (await htmlBlob.text().toDart).toDart;
    }

    return RichClipboardData(
      text: text,
      html: html,
    );
  }

  @override
  Future<void> setData(RichClipboardData data) async {
    final clipboard = window.navigator.clipboard as Clipboard?;
    if (clipboard == null) {
      return;
    }

    final obj = js.JSObject();
    bool got = false;
    data.toMap().entries.where((entry) => entry.value != null).forEach((entry) {
      got = true;
      obj[entry.key] = Blob(
        [entry.value!.toJS].toJS,
        BlobPropertyBag(type: entry.key),
      );
    });
    final items = <ClipboardItem>[if (got) ClipboardItem(obj)];
    clipboard.write(items.toJS);
  }
}
