
library webview;

import 'dart:html';
import 'dart:json';
import 'package:js/js.dart' as js;
import 'package:web_ui/web_ui.dart';
import 'package:web_ui/watcher.dart' as watcher;

class Webview extends WebComponent {
 
  static const Map _EVENTS = const { 
    'exit' : const ['processId', 'reason'],
    'loadabort' : const ['url', 'isTopLevel', 'reason'],
    'loadcommit' : const ['url', 'isTopLevel'],
    'loadredirect' : const ['oldUrl', 'newUrl', 'isTopLevel'],
    'loadstart' : const ['url', 'isTopLevel'],
    'loadstop' : const [],
    'sizechanged': const ['oldHeight', 'oldWidth', 'newHeight', 'newWidth']
  };
  
  static bool _supported = true;
  /// Gets whether or not the webview element is supported by the platform.
  static bool get supported => _supported;
  
  static bool _injected = false;
  static _inject(then) {
    if(_injected) then();
    else {
      // Test if the js script is already injected.
      try {
        _supported = js.scoped(() => js.context.isWebviewSupported());
        // Webview.js is injected, continue.        
        then();
      } catch (e) {
        // Webview.js is not yet injected, so append it to body.
        var script = new ScriptElement();
        script.type = "text/javascript";
        script.src = "packages/webview/webview.js";
        script.on.load.add((e) {
          // Script loaded, check support and continue.
          _supported = js.scoped(() => js.context.isWebviewSupported());
          then();
        });    
        document.body.append(script);
      } finally {
        _injected = true;
      }
    }
  }

  String _src = '';
  /// Reflects the src HTML attribute, containing the address of the content to
  /// be embedded.
  String get src => available ? _call(() => _webview.getSrc()) : _src;
         set src(value) => available ? _call(() => _webview.setSrc(value)) :
                                       _src = value;
         
  /// Gets whether this webview instance is available;  The webview is available
  /// once it is inserted in the DOM _and_ the javascript behavior is loaded.
  bool get available => _webview != null;
         
  bool get canGoBack => _call(() => _webview.canGoBack());
  
  bool get canGoForward => _call(() => _webview.canGoForward());
  
  _Window _contentWindow;
  WindowBase get contentWindow {
    if(_contentWindow == null) {
      _contentWindow = _call(() => new _Window(_webview.contentWindow()));
    }
    return _contentWindow;
  }
  
  int get processId => _call(() => _webview.getProcessId());
  
  js.Callback _onEvent;
  js.Proxy _webview;
  
  void inserted() {
    _inject(() {
      js.scoped(() {
        _onEvent = new js.Callback.many(_dispatch);
        _webview = js.retain(
            new js.Proxy(js.context.Webview, children[1], _src, _onEvent));
      });
      watcher.dispatch();
    });
  }
  
  void removed() {
    js.scoped(() {
      _onEvent.dispose();
      js.release(_webview);
      if(_contentWindow != null) _contentWindow._dispose();
    });
  }

  void back() => _call(() => _webview.back());  
  
  void forward() => _call(() => _webview.forward());
  
  void reload() => _call(() => _webview.reload());  
  
  void stop() => _call(() => _webview.stop());  
  
  void terminate() => _call(() => _webview.terminate());
  
  bool _dispatch(e) {
    // TODO(rms): explore better ways to do this
    var detail = new Map();
    var props = _EVENTS[e.type];
    for(var p in props) {      
      switch(p) {
        case 'isTopLevel' : detail['isTopLevel'] = e.isTopLevel; break;  
        case 'oldHeight' : detail['oldHeight'] = e.oldHeight; break;
        case 'oldUrl' : detail['oldUrl'] = e.oldUrl; break;
        case 'oldWidth' : detail['oldWidth'] = e.oldWidth; break;
        case 'newHeight' : detail['newHeight'] = e.newHeight; break;
        case 'newUrl' : detail['newUrl'] = e.newUrl; break;
        case 'newWidth' : detail['newWidth'] = e.newWidth; break;
        case 'processId' : detail['processId'] = e.processId; break;
        case 'reason' : detail['reason'] = e.reason; break;
        case 'url': detail['url'] = e.url; break;
      }
    }
    on[e.type].dispatch(
      new CustomEvent(e.type, e.bubbles, e.cancelable, JSON.stringify(detail))); 
  }
  
  _call(f()) {
    if(!supported) throw new UnsupportedError('Webview is not supported.');
    if(!available) throw new StateError('Webview instance is not available.');
    return js.scoped(f);
  }
}

class _Window implements WindowBase {
  
  bool get closed => js.scoped(() => _proxy.closed);  
  
  HistoryBase get history { throw new UnimplementedError(); }
  
  LocationBase get location { throw new UnimplementedError(); }
  
  WindowBase get opener { throw new UnimplementedError(); }
  
  WindowBase get parent { throw new UnimplementedError(); }
  
  WindowBase get top { throw new UnimplementedError(); }
  
  js.Proxy _proxy;
  
  _Window(js.Proxy proxy) {_proxy = js.retain(proxy); }
  
  void _dispose() => js.release(_proxy);
  
  void close() => js.scoped(() => _proxy.close()); 

  void postMessage(message, String targetOrigin, [List messagePorts]) {
    throw new UnimplementedError();
  }
}
