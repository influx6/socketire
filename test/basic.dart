library test;

import 'dart:io';
import 'dart:async';

main(){
    	
  var handler = (socket){
  	print('got socket $socket');
  	socket.listen((m){
  		
  		var r = socket;

  		r.add('hello!');

  		print('socket message: $m');

			if(m == 'hi'){
				r.add('0');
				r.add('hello client!');
			}
			if(m == 'data'){
				r.add('1');
				r.add("here's the details request: { name: chicken}");
			}
			if(m == 'thanks'){
				r.add('2');
				r.add('you welcome bye!');
			}

  	});
  };

  HttpServer.bind('127.0.0.1', 3000).then((server){
      server.transform(new WebSocketTransformer()).listen(handler);
  },onError: (e){
      print('server error: $e');
  });  
}