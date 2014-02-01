#Socketire
	Provides a simplified http server depending upon condition provided or using the default can switch a request to a websocket request or serve as a standard http request,its a simplified httpserver wrapper with a basic file server and directory server,nothing fancy.Also provides a client implementation for websocket and a client side postMessage wrapper

##Examples

	library socketire.spec;

	import 'package:path/path.dart' as paths;
	import 'dart:io';
	import 'package:socketire/server.dart';

	void main(){
		
		allows the supply of 4 optional elements
		1. the ip address to use
		2. the port to use
		3. a functional to validate wether its a http request
		4. a functional to validate wether its a websocket request

		var socket = SocketireServer.create();

		socket.initGuardedFS('.');

		var testReg = new RegExp(r'^test');

		socket..requestFile('/',new RegExp(r'^/$'),'./test/assets/index.html')
		..requestFile('posts',new RegExp(r'^/posts'),'./test/assets/post.html')

		//when delivering a resource with a different name than that of its directory name,ensure to use the request stream as below
		//to fix the name conversion eg. from /assets/index.html to /text/index.html and vise-versal
		..requestFS('assets',new RegExp(r'^/assets'),'./test')
		..request('ws',new RegExp(r'^/ws'));

		socket.errors.on((r){
			r.httpSend('Not Found!');
		});

		socket.info.on((r){
			print('#requesting ${r.request.uri}');
		});

		//should be called before calling socket.ready if called after,it cant garanted firing incase if the server is created
		//before even the call to socket.initd is called up, its done this way to allow re-initialization of your server settings
		//even in cases of server failure or reboot when using runZones
		socket.initd.on((bb){

				//a necessecity to fix the conversion from assets to test name 
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

		//the httpServer is optional and can be omitted,when omitted,socketire will simple create a server bound to 
		// the local ip and at port 3000,unless if specifiied in the create constructor
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

##Todo
	- Simplify socketire's life!