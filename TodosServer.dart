#import("dart:io");
#import("dart:json");
#import("Express.dart");
#import("vendor/DartRedisClient/Mixin.dart");
#import("vendor/DartRedisClient/RedisClient.dart");

void main(){

  RedisClient client = new RedisClient();

  Express app = new Express();

  app.use(new StaticFileHandler());

  app.get("/todos", (HttpContext ctx){
    client.keys("todo:*").then((keys){
      client.mget(keys).then((values) {
        ctx.send(values, asFormat:"json");
      });
    });
  });

  app.get("/todos/:id", (HttpContext ctx){
    var id = ctx.param("id");
    client.get("todo:$id}").then((todo){
      if (todo != null)
        ctx.send(todo, asFormat:"json");
      else
        ctx.notFound("todo $id does not exist");
    });
  });

  app.post("/todos", (HttpContext ctx){
    ctx.readAsJson().then((x){
      var todo = $(x).defaults({"content":null,"done":false,"order":0});
      client.incr("ids:todo").then((newId){
        todo["id"] = newId;
        client.set("todo:$newId", todo);
        ctx.send(todo, asFormat:"json");
      });
    });
  });

  app.put("/todos/:id", (HttpContext ctx){
    var id = ctx.param("id");
    ctx.readAsJson().then((todo){
      client.set("todo:$id", todo);
      ctx.send(todo, asFormat:"json");
    });
  });

  app.delete("/todos/:id", (HttpContext ctx){
    client.del("todo:${ctx.param('id')}");
    ctx.end();
  });

  print("listening on 8000...");
  app.listen("127.0.0.1", 8000);
}

