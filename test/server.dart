library socketire.spec;

import 'dart:io';
import 'package:socketire/socketire-server.dart';

void main(){

	var socket = Socketire.createFrom(HttpServer.bind('127.0.0.1',3000),
		SocketireRequestHelper.matchRequest(new RegExp(r'^/ws')));

	var index = new File('./web/index.html');
	var clientdart = new File('./client.dart');
	var client = new RegExp(r'client.dart');


	socket..space('user',SocketireRequestHelper.matchRequest(new RegExp(r'^/user')))
	..space('assets',SocketireRequestHelper.matchRequest(new RegExp(r'^/assets')))
	..space('posts',SocketireRequestHelper.matchRequest(new RegExp(r'^/posts')))
	..space('ws',SocketireRequestHelper.matchRequest(new RegExp(r'^/ws')));

	socket.errors.on((r){
		r.httpSend('Not Found!');
	});

	socket.info.on((r){
		if(r is WebSocketRequestServer) print('#requesting ${r.request.uri}');
		else print('#log $r');
	});

	socket.ready().then((_){

		socket.stream('assets').on((r){

			var path = r.request.uri.path;				
			var ast = path.replaceAll('/assets','.');

			var asset = new File(ast);
			return asset.readAsString().then((content){
				r.httpSend(content);
			});

		});

		socket.stream('user').on((r){
			if(!r.isHttp) return;
			
			r.headers('Content-Type','text/html');
			index.readAsString().then((c){
				r.httpSend(c);
			});
		});

		socket.stream('ws').on((r){

			print('socketire : ${r}');
			if(!r.isSocket) return;

			print('socket message: ${r.message}');

			r.socketSend('user#Welcome to users!');
			r.socketSend('awaiting');
		});
	

	});


}