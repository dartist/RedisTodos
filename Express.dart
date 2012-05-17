#library("Express");
#import("dart:io");
#import("dart:json");
#import("vendor/DartRedisClient/Mixin.dart");

interface Module {
  void register(HttpServer server);
  void execute(HttpRequest req, HttpResponse res);
}

typedef void RequestHandler (HttpContext ctx);

class Express {
  Map<String, LinkedHashMap<String,RequestHandler>> _verbPaths;
  List<String> _verbs = const ["GET","POST","PUT","DELETE","PATCH","HEAD","OPTIONS","ANY"];
  List<Module> _modules;
  HttpServer server;

  Express() {
    _verbPaths = new Map<String, LinkedHashMap<String,RequestHandler>>();
    _verbs.forEach((x) => _verbPaths[x] = {});
    _modules = new List<Module>();
  }

  void use(Module module) => _modules.add(module);

  get(handlerMapping, RequestHandler handler) =>
      _verbPaths["GET"][handlerMapping] = handler;

  post(handlerMapping, RequestHandler handler) =>
      _verbPaths["POST"][handlerMapping] = handler;

  put(handlerMapping, RequestHandler handler) =>
      _verbPaths["PUT"][handlerMapping] = handler;

  delete(handlerMapping, RequestHandler handler) =>
      _verbPaths["DELETE"][handlerMapping] = handler;

  patch(handlerMapping, RequestHandler handler) =>
      _verbPaths["PATCH"][handlerMapping] = handler;

  head(handlerMapping, RequestHandler handler) =>
      _verbPaths["HEAD"][handlerMapping] = handler;

  options(handlerMapping, RequestHandler handler) =>
      _verbPaths["OPTIONS"][handlerMapping] = handler;

  any(handlerMapping, RequestHandler handler) =>
      _verbPaths["ANY"][handlerMapping] = handler;

  void operator []=(String handlerMapping, RequestHandler handler) =>
    any(handlerMapping, handler);

  bool handlesRequest(HttpRequest req) {
    bool foundMatch = _verbPaths[req.method] != null &&
    ( _verbPaths[req.method].getKeys().some((x) => pathMatches(x, req.path))
      || _verbPaths["ANY"].getKeys().some((x) => pathMatches(x, req.path)) );
    if (foundMatch) print("match found for ${req.method} ${req.path}");
    return foundMatch;
  }
  
  bool isMatch(String verb, String route, HttpRequest req) =>
      (req.method == verb || verb == "ANY") && pathMatches(route, req.path);

  void listen([String host="127.0.0.1", int port=80]){
    server = new HttpServer();
    _verbPaths.forEach((verb, handlers) =>
        handlers.forEach((route, handler) =>
            server.addRequestHandler((HttpRequest req) => isMatch(verb, route, req),
              (HttpRequest req, HttpResponse res) { new HttpContext(route, handler).execute(req, res); }
            )
        )
    );
    _modules.forEach((module) => module.register(server));
    server.listen(host, port);
  }
}

class HttpContext {
  String routePath;
  String reqPath;
  RequestHandler handler;
  HttpRequest  req;
  HttpResponse res;
  Map<String,String> params;
  String _format;

  HttpContext(this.routePath, RequestHandler this.handler);

  execute(HttpRequest request, HttpResponse response){
    this.req=request;
    this.res=response;
    print("handling ${req.path}");
    handler(this);
  }

  String param(String name) {
    if (params == null){
      params = pathMatcher(routePath, req.path);
    }
    return params[name];
  }

  Future<List<int>> readAsBytes() {
    Completer<List<int>> completer = new Completer<List<int>>();    
    var stream = req.inputStream;
    var chunks = new _BufferList();
    stream.onClosed = () {
      completer.complete(chunks.readBytes(chunks.length));
    };
    stream.onData = () {
      var chunk = stream.read();
      chunks.add(chunk);
    };
    stream.onError = completer.completeException;
    return completer.future;
  }

  Future<String> readAsText([Encoding encoding = Encoding.UTF_8]) {
//    var decoder = _StringDecoders.decoder(encoding);
    return readAsBytes().transform((bytes) {
      return new String.fromCharCodes(bytes);
//      decoder.write(bytes);
//      return decoder.decoded;
    });
  }
 
  Future<Object> readAsJson([Encoding encoding = Encoding.UTF_8]) => 
      readAsText(encoding).transform((json) => JSON.parse(json));

  set format(String value) {
    _format = value;
    String _contentType = contentTypes[value];
    if (_contentType != null)
      contentType = _contentType;
  }

  set contentType(String value) =>
      res.headers.set(HttpHeaders.CONTENT_TYPE, value);

  void write(Object value){
    switch(_format){
      case "json":
        res.outputStream.writeString(JSON.stringify(value));
      break;
      default:
        if (value is List<int>)
          res.outputStream.write(value);
        else
          res.outputStream.writeString(value.toString());
        break;
    }
  }

  void send(Object value, [String asFormat]){
    if (asFormat != null)
      format = asFormat;

    write(value);
    res.outputStream.close();
  }

  void end([int httpStatus, String statusReason]){
    if (httpStatus != null) {
      res.statusCode = HttpStatus.NOT_FOUND;
    }
    if (statusReason != null){
      res.reasonPhrase = statusReason;
    }
    res.outputStream.close();
  }

  void notFound([String statusReason]) => end(HttpStatus.NOT_FOUND, statusReason);
}

Map<String, String> contentTypes = const {
  "txt" : "text/plain",
  "css" : "text/css",
  "htm" : "text/html; charset=UTF-8",
  "html": "text/html; charset=UTF-8",
  "dart": "application/dart",
  "js"  : "application/javascript",
  "json": "application/json",
  "gif" : "image/gif",
  "jpg" : "image/jpeg",
  "jpeg": "image/jpeg",
  "png" : "image/png",
};
List<String> binaryExts = const ["image/jpeg","image/gif","image/png"];

String getContentType(File file) {
  String ext = file.name.split('.').last();
  return contentTypes[ext] != null ? contentTypes[ext] : null;
}

class StaticFileHandler implements Module {

  void register(HttpServer server) =>
      server.addRequestHandler((_) => true, execute);

  void execute(HttpRequest req, HttpResponse res){
    String path = (req.path.endsWith('/')) ? ".${req.path}index.html" : ".${req.path}";
    print("serving $path");

    File file = new File(path);
    file.exists().then((bool exists) {
      if (exists) {
        String contentType = getContentType(file);
        bool isBinary = binaryExts.indexOf(contentType) >= 0;
        res.headers.set(HttpHeaders.CONTENT_TYPE, contentType);
        if (isBinary){
          file.readAsBytes().then((List<int> bytes) {
            res.outputStream.write(bytes);
            res.outputStream.close();
          });
        } else {
          file.readAsText().then((String text) {
            res.outputStream.writeString(text);
            res.outputStream.close();
          });
        }
      } else {
        res.statusCode = HttpStatus.NOT_FOUND;
        res.outputStream.close();
      }
    });
  }

}

Express express() => new Express();

bool pathMatches(String matchPath, String withPath) => pathMatcher(matchPath, withPath) != null;

//  print(pathMatcher("/tests", "/tests"));
//  print(pathMatcher("/tests/:id", "/tests/1"));
//  print(pathMatcher("/tests/:id", "/tests"));
//  print(pathMatcher("/tests/:id", "/rests"));
//  print(pathMatcher("/todos", "/todos.css"));
//  print(pathMatcher("/todos", "/todos.js"));
//  print(pathMatcher("/users/:id/todos/:todoId", "/users/1/todos/2"));

Map<String,String> pathMatcher(String matchPath, String withPath){
  Map params = {};
  if (matchPath == withPath) return params;
  List<String> matchComponents = matchPath.split("/");
  List<String> pathComponents = withPath.split("/");
  if (matchComponents.length == pathComponents.length){
    for (int i=0; i<matchComponents.length; i++){
      String match = matchComponents[i];
      String path = pathComponents[i];
      if (match == path) continue;
      if (match.startsWith(":")) {
        params[match.substring(1)] = path;
        continue;
      }
      return null;
    }
    return params;
  }
  return null;
}

class _BufferList {
  _BufferList() {
    clear();
  }

  void add(List<int> buffer, [int offset = 0]) {
    assert(offset == 0 || _buffers.isEmpty());
    _buffers.addLast(buffer);
    _length += buffer.length;
    if (offset != 0) _index = offset;
  }

  List<int> get first() => _buffers.first();

  int get index() =>  _index;

  int peek() => _buffers.first()[_index];

  int next() {
    int value = _buffers.first()[_index++];
    _length--;
    if (_index == _buffers.first().length) {
      _buffers.removeFirst();
      _index = 0;
    }
    return value;
  }

  List<int> readBytes(int count) {
    List<int> result;
    if (_length == 0 || _length < count) return null;
    if (_index == 0 && _buffers.first().length == count) {
      result = _buffers.first();
      _buffers.removeFirst();
      _index = 0;
      _length -= count;
      return result;
    } else {
      int firstRemaining = _buffers.first().length - _index;
      if (firstRemaining >= count) {
        result = _buffers.first().getRange(_index, count);
        _index += count;
        _length -= count;
        if (_index == _buffers.first().length) {
          _buffers.removeFirst();
          _index = 0;
        }
        return result;
      } else {
        result = new Uint8List(count);
        int remaining = count;
        while (remaining > 0) {
          int bytesInFirst = _buffers.first().length - _index;
          if (bytesInFirst <= remaining) {
            result.setRange(count - remaining,
                            bytesInFirst,
                            _buffers.first(),
                            _index);
            _buffers.removeFirst();
            _index = 0;
            _length -= bytesInFirst;
            remaining -= bytesInFirst;
          } else {
            result.setRange(count - remaining,
                            remaining,
                            _buffers.first(),
                            _index);
            _index = remaining;
            _length -= remaining;
            remaining = 0;
            assert(_index < _buffers.first().length);
          }
        }
        return result;
      }
    }
  }

  void removeBytes(int count) {
    int firstRemaining = first.length - _index;
    assert(count <= firstRemaining);
    if (count == firstRemaining) {
      _buffers.removeFirst();
      _index = 0;
    } else {
      _index += count;
    }
    _length -= count;
  }

  int get length() => _length;

  bool isEmpty() => _buffers.isEmpty();

  void clear() {
    _index = 0;
    _length = 0;
    _buffers = new Queue();
  }

  int _length;  // Total number of bytes remaining in the buffers.
  Queue<List<int>> _buffers;  // List of data buffers.
  int _index;  // Index of the next byte in the first buffer.
}
