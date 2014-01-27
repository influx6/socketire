library socketire.spec;

import 'dart:io';
import 'package:socketire/socketire-server.dart';

void main(){

	var socket = SocketireServer.createFrom(HttpServer.bind('127.0.0.1',3000),
		SocketireRequestHelper.matchRequest(new RegExp(r'^/ws')));

	var index = new File('./web/index.html');
	var clientdart = new File('./client.dart');
	var client = new RegExp(r'client.dart');


	socket..request('home',new RegExp(r'^/home'))
	..requestFS('assets',new RegExp(r'^/assets'),'./test')
	..request('posts',new RegExp(r'^/posts'))
	..request('ws',new RegExp(r'^/ws'));

	socket.errors.on((r){
		r.httpSend('Not Found!');
	});

	socket.info.on((r){
		if(r is WebSocketRequestServer) print('#requesting ${r.request.uri}');
		else print('#log $r');
	});

	socket.ready().then((_){

		socket.stream('assets').on((r){

			print('assert request');
			print(r);
			print(r.spec);
			print(r.request.uri.path);

			// var path = r.request.uri.path;				
			// var ast = path.replaceAll('/assets','.');

			// var asset = new File(ast);
			// return asset.readAsString().then((content){
			// 	r.httpSend(content);
			// });

		});

		socket.stream('home').on((r){
			if(!r.isHttp) return;
			
			r.headers('Content-Type','text/html');
			index.readAsString().then((c){
				r.httpSend(c);
			});
		});

		socket.stream('ws').on((r){
			print('socket message: ${r.message}');

			if(r.message == 'hi'){
				r.socketSend('0');
				r.socketSend('hello client!');
			}
			if(r.message == 'data'){
				r.socketSend('1');
				r.socketSend("here's the details request: { name: chicken}");
			}
			if(r.message == 'thanks'){
				r.socketSend('2');
				r.socketSend('you welcome bye!');
			}
		});
	

	});


}