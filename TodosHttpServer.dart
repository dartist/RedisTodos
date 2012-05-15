#import("dart:io");
#import("vendor/DartRedisClient/Mixin.dart");
#import("vendor/DartRedisClient/RedisClient.dart");

Map<String,String> pathMatcher(String matchPath, String withPath){
  if (matchPath == withPath) return {};
  List<String> matchComponents = matchPath.split("/");
  List<String> pathComponents = withPath.split("/");
  if (matchPath.length == pathComponents.length){
    for (int i=0; i<matchComponents.length; i++){

    }
  }
  return null;
}

void main(){
  HttpServer server = new HttpServer();
//  server.addRequestHandler((HttpRequest req) => (req.path == "/time"), wsHandler.onRequest);
  handlers.forEach((path, handler) =>
      server.addRequestHandler((HttpRequest req) => new RegExp(path, false, true).hasMatch(req.path), handler));
  server.addRequestHandler((_) => true, fileServer);
  server.listen("127.0.0.1", 8080);
}

Map<String, Function> handlers = {
  "/todos" : (HttpRequest req, HttpResponse res){
    res.headers.set(HttpHeaders.CONTENT_TYPE, contentType("txt"));
    res.outputStream.writeString("/todos == ${req.path}");
    res.outputStream.close();
  },
  "/todos/:id" : (HttpRequest req, HttpResponse res){
    res.headers.set(HttpHeaders.CONTENT_TYPE, contentType("txt"));
    res.outputStream.writeString("/todos == ${req.path}");
    res.outputStream.close();
  }
};

Map<String, String> contentTypes = const {
  "txt" : "text/plain",
  "html": "text/html; charset=UTF-8",
  "dart": "application/dart",
  "js": "application/javascript",
};

String contentType(File file) => contentTypes[file.name.split('.').last()];

void fileServer(HttpRequest req, HttpResponse res){
  String path = (req.path.endsWith('/')) ? ".${req.path}index.html" : ".${req.path}";
  print("serving $path");

  File file = new File(path);
  file.exists().then((bool exists) {
    if (exists) {
      file.readAsText().then((String text) {
        resp.headers.set(HttpHeaders.CONTENT_TYPE, contentType(file));
        resp.outputStream.writeString(text);
        resp.outputStream.close();
      });
    } else {
      resp.statusCode = HttpStatus.NOT_FOUND;
      resp.outputStream.close();
    }
  });
}
