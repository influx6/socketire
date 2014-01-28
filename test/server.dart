library socketire.spec;

import 'dart:async';
import 'package:hub/hub.dart';
import 'package:path/path.dart' as paths;
import 'dart:io';
import 'package:socketire/socketire-server.dart';
import 'package:streamable/streamable.dart' as sm;

void main(){

	var socket = SocketireServer.createFrom(HttpServer.bind('127.0.0.1',3000));

	socket.initGuardedFS('.');

	var testReg = new RegExp(r'^test');

	socket..requestFile('/',new RegExp(r'^/$'),'./test/web/index.html')
	..requestFile('posts',new RegExp(r'^/posts'),'./test/web/post.html')
	..requestFS('assets',new RegExp(r'^/assets'),'./test')
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
			return r.request.uri.path.replaceAll('/assets','.');
		},(path){
			return paths.join('/assets',path.replaceAll(testReg,''));
		}));

		socket.stream('assets').on((r){
			if(!r.options.get('isRootDirectory')) return null;
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

		socket.stream('/').on(StaticRequestHelpers.renderFileRequest((r,d){
			r.httpSend(d);
		}));

		socket.stream('posts').on(StaticRequestHelpers.renderFileRequest((r,d){
			r.httpSend(d);
		}));

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