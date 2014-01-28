library socketire.spec;

import 'dart:async';
import 'package:hub/hub.dart';
import 'package:path/path.dart' as paths;
import 'dart:io';
import 'package:socketire/socketire-server.dart';
import 'package:streamable/streamable.dart' as sm;

void main(){

	var socket = SocketireServer.createFrom(HttpServer.bind('127.0.0.1',3000),
		SocketireRequestHelper.matchRequest(new RegExp(r'^/ws')));

	var index = new File(paths.normalize('./test/web/index.html'));
	var testReg = new RegExp(r'^test|\\test\\');
	var dotReg = new RegExp(r'..');

	socket..request('/',new RegExp(r'^/$'))
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


		socket.stream('assets').transformer.on(StaticRequestHelpers.fsTransformer((r){
			var root = r.request.uri.path.replaceAll('/assets','.');
			return  root;
		},(path){
			var root = paths.normalize(path.replaceAll('..','').replaceAll(testReg,'').replaceFirst('\\',''));
			return paths.normalize(paths.join('/assets',root));
		}));

		socket.stream('assets').on((r){
			print('root directory :${r.options}');

			if(!r.options.get('isRootDirectory')) return;
				return r.spec.listDirectory().then((_){

					r.headers('Content-Type','text/html');
					var data = new List.from(['<ul>']);
					r.options.get('handler')(r,_).then((list){
						data.add('<li><a href="/">root</li>');
						data.add('<li><a href=".">back</li>');
						list.forEach((n){ 
							data.add('<li><a href="$n">$n</li>'); 
						});
						data.add('</ul>');
						r.httpSend(data.join(''));
					});

			});
		});

		socket.stream('assets').on((r){
			if(!r.options.get('valid') || r.options.get('isRootDirectory')) return;

				r.spec.get(r.options.get('realPath'),(dir){
					dir.then((_){
						r.headers('Content-Type','text/html');
						var data = new List.from(['<ul>']);
						r.options.get('handler')(r,_).then((list){
							data.add('<li><a href="/">root</li>');
							data.add('<li><a href=".">back</li>');
							list.forEach((n){ data.add('<li><a href="$n">$n</li>'); });
							data.add('</ul>');
							r.httpSend(data.join(''));
						});
					});
				},(file){
					file.then(r.httpSend);
				});

		});



		socket.stream('/').on((r){
			if(!r.isHttp) return;
			
			r.headers('Content-Type','text/html');
			index.readAsString().then((c){
				r.httpSend(c);
			});
		});


		socket.stream('posts').on((r){
			if(!r.isHttp) return;
			
			r.headers('Content-Type','text/html');
			r.httpSend('Welcome to Posts!');
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