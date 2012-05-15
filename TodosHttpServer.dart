#import("dart:io");
#import("vendor/DartRedisClient/Mixin.dart");
#import("vendor/DartRedisClient/RedisClient.dart");

Map<String,String> pathMatcher(String matchPath, String withPath){
  Map params = {};
  if (matchPath == withPath) return params;
  List<String> matchComponents = matchPath.split("/");
  List<String> pathComponents = withPath.split("/");
  print("$matchComponents : $pathComponents");
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

void main(){
//  print(pathMatcher("/tests", "/tests"));
//  print(pathMatcher("/tests/:id", "/tests/1"));
//  print(pathMatcher("/tests/:id", "/tests"));
//  print(pathMatcher("/tests/:id", "/rests"));
  Map<String, Function> handlers = {
    "/todos" : (HttpRequest req, HttpResponse res){
      res.headers.set(HttpHeaders.CONTENT_TYPE, "text/plain");
      res.outputStream.writeString("/todos == ${req.path}");
      res.outputStream.close();
    },
    "/todos/:id" : (HttpRequest req, HttpResponse res){
      res.headers.set(HttpHeaders.CONTENT_TYPE, "text/plain");
      res.outputStream.writeString("/todos == ${req.path}");
      res.outputStream.close();
    }
  };

  HttpServer server = new HttpServer();
  handlers.forEach((path, handler) =>
      server.addRequestHandler((HttpRequest req) => pathMatcher(path, req.path) != null, handler));
  server.addRequestHandler((_) => true, fileServer);
  server.listen("127.0.0.1", 8080);
}

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
        res.headers.set(HttpHeaders.CONTENT_TYPE, contentType(file));
        res.outputStream.writeString(text);
        res.outputStream.close();
      });
    } else {
      res.statusCode = HttpStatus.NOT_FOUND;
      res.outputStream.close();
    }
  });
}
