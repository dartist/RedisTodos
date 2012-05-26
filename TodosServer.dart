#import("dart:io");
#import("dart:json");
#import("vendor/Express/Express.dart");
#import("vendor/Mixins/Mixin.dart");
#import("vendor/DartRedisClient/RedisClient.dart");

void main(){

  RedisClient client = new RedisClient();

  Express app = new Express();

  app
    .use(new StaticFileHandler())

    .get("/todos", (HttpContext ctx){
      client.keys("todo:*").then((keys) =>
        client.mget(keys).then(ctx.sendJson)
      );
    })

    .get("/todos/:id", (HttpContext ctx){
      var id = ctx.param("id");
      client.get("todo:$id}").then((todo) =>
        todo != null ?
          ctx.sendJson(todo) :
          ctx.notFound("todo $id does not exist")
      );
    })

    .post("/todos", (HttpContext ctx){
      ctx.readAsJson().then((x){
        client.incr("ids:todo").then((newId){
          var todo = $(x).defaults({"content":null,"done":false,"order":0});
          todo["id"] = newId;
          client.set("todo:$newId", todo);
          ctx.sendJson(todo);
        });
      });
    })

    .put("/todos/:id", (HttpContext ctx){
      var id = ctx.param("id");
      ctx.readAsJson().then((todo){
        client.set("todo:$id", todo);
        ctx.sendJson(todo);
      });
    })

    .delete("/todos/:id", (HttpContext ctx){
      client.del("todo:${ctx.param('id')}");
      ctx.send();
    })

    .listen("0.0.0.0", 8000);
  
  print("listening on 8000...");
}

