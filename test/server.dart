library socketire.spec;


import 'package:path/path.dart' as paths;
import 'dart:io';
import 'package:socketire/server.dart';

void main(){

	var socket = SocketireServer.create('127.0.0.1',3001);

	socket.initGuardedFS('.');

	var testReg = new RegExp(r'^test');

	socket..requestFile('/',new RegExp(r'^/$'),'./test/assets/index.html')
	..requestFile('posts',new RegExp(r'^/posts'),'./test/assets/post.html')
	..requestFS('assets',new RegExp(r'^/assets'),'./test')
	..request('ws',new RegExp(r'^/ws'));

	socket.errors.on((r){
		if(r is WebSocketRequestServer) r.httpSend('Not Found!');
	});

	socket.info.on((r){
		print('#requesting ${r.request.uri}');
	});

	//should be called before calling socket.ready
	socket.initd.on((bb){

			socket.stream('assets').transformer.on(StaticRequestHelpers.fsTransformer((r){
					return r.request.uri.path.replaceFirst('/assets','.');
				},(path){
					return  paths.join('/assets',path.replaceAll(testReg,''));
				}));

				socket.stream('assets').on((r){
					if(r.isSocket) return;

					if(!r.options.get('isRootDirectory')) return null;
						return r.spec.listDirectory().then((_){
							if(_ is Exception) return r.httpSend('Resource Not Found (404)!');

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
					if(r.isSocket) return;
					
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
						},(e){
							return r.httpSend('Resource Not Found (404)!');
						});

				});

				socket.stream('/').on(StaticRequestHelpers.renderFileRequest((r,d){
					if(r.isSocket) return;
					r.httpSend(d);
				}));

				socket.stream('posts').on(StaticRequestHelpers.renderFileRequest((r,d){
					if(r.isSocket) return;
					r.httpSend(d);
				}));

				socket.stream('ws').on((r){

					print('socket message: ${r.message}');
					
					if(!r.isSocket) return;

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
	
	//you can pass in a httpserver future to ready to use a custom server
	/* i.e 
		socket.ready(HttpServer.bind('127.0.0.1',3000)).then((f){

			print('socket server: $f');

		});

	*/

	socket.ready().then((f){

		print('socket server: $f');

	});


}