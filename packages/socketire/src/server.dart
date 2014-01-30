library socketire;

import 'dart:io';
import 'dart:async';
import 'package:hub/hub.dart';
import 'package:path/path.dart' as paths;
import 'package:streamable/streamable.dart' as sm;
import 'package:guardedfs/guardedfs.dart';

part 'helpers.dart';

class RequestSpecsServer extends RequestSpecs{

	static create(s,f) => new RequestSpecsServer(s,f);

	RequestSpecsServer(String space,Function handle): super(space,handle);

	void setSocket(socket,request,Function m){
		this._socket = socket;
		this._socket.listen((mesg){
			m(mesg,this.stream,this.socket,request);
		},onError:(e){ throw e; });
	}

	void close(){
		this._socket.close();
		this._socket = null;
		this.stream.close();
	}

}

class FileRequestSpecServer extends RequestSpecsServer{
	GuardedFile file;

	static create(fs,s,f,n) => new FileRequestSpecServer(fs,s,f,n);

	FileRequestSpecServer(this.file,String space,Function handle,String path): super(space,handle);

	dynamic readAsString() => this.file.readAsString();

	dynamic stat() => this.file.stat();
}

var _rootReg = new RegExp(r'(\.+\/\.*)$');

class FSRequestSpecServer extends RequestSpecsServer{
	GuardedFS fs;
	Regexp pathChecker;
	String point;
	dynamic root;

	static create(s,f,n,w) => new FSRequestSpecServer(s,f,n,w);

	FSRequestSpecServer(String space,Function handle,String path,bool readonly): super(space,handle){
		this.point = path;
		this.pathChecker = new RegExp('^'+path.replaceFirst('..',''));
		this.fs = GuardedFS.create(paths.normalize(paths.join(path,'.')),readonly);
		this.root = paths.normalize(paths.join(path,'..'));
	}


	bool validatePath(String path){
		// if(_rootReg.hasMatch(path) || path == '/') return true;
		if(paths.isWithin(this.root,path) || this.root == paths.normalize(path) || this.pathChecker.hasMatch(path)) return true;
		return false;
	}

	bool isRootDirectory(String path){
		// if(_rootReg.hasMatch(path) || path == '/') return true;
		var root = paths.normalize(paths.join(path,'.'));
		if(root == this.root || root == '.' || root == './') return true;
		return false;
	}

	void listDirectory([bool recursive]){
		return this.fs.directoryListsAsString();
	}

	Future fsCheck(String path){
		return new Future.value((FileSystemEntity.typeSync(path) == FileSystemEntityType.NOT_FOUND ? new Exception('NOT FOUND!') : path));
	}

	Future get(String path,Function dir,Function file,Function failure){
		var point = paths.normalize(paths.join(this.point,path));
		return this.fsCheck(point).then((_){
			if(_ is Exception){ failure(_); return _; };
			if(FileSystemEntity.typeSync(_) == FileSystemEntityType.FILE || FileSystemEntity.typeSync(_) == FileSystemEntityType.LINK) 
				return file(this.readFile(path));
			if(FileSystemEntity.typeSync(_) == FileSystemEntityType.DIRECTORY) return dir(this.getDirectoryLists(path));
		});
	}

	dynamic getDirectory(String path,[bool recursive]){
		var point = paths.normalize(paths.join(this.point,path));
		return this.fsCheck(point).then((_){
			if(_ is Exception) return _;
			return this.fs.Dir(path);
		});
	}

	dynamic getDirectoryLists(String path,[bool recursive]){
		return this.getDirectory(path,recursive).then((_){
			if(_ is Exception) return _;
			return _.directoryListsAsString();
		});
	}

	dynamic readFile(String name){
		if(!this.validatePath(paths.normalize(paths.join(this.point,name)))) return null;
		var file = this.fs.File(name);
		return file.exists().then((exist){
		  if(!exist) throw "File Not Exists";
		  var data = new Completer();
		  file.readAsString().then((d){
		  	data.complete(d);
		  },onError:(e){
		  	file.readAsBytes().then((d){ 
		  		data.complete(d); 
		  	});
	  	  });

		  return data.future;
		});

	}

	Future createFile(String name,dynamic data){
		if(!this.validatePath(paths.normalize(paths.join(this.point,name)))) return null;
		if(!this.fs.isWritable) return null;
		var file = this.fs.File(name);
		var data = new Completer();
		file.writeAsString(data).then((file){
			data.complete(file);
		},onError:(e){
			file.writeAsBytes(data).then((file){ data.complete(file); });
		});

		return data.future;
	}

	Future appendFile(String name,dynamic data){
		if(!this.validatePath(paths.normalize(paths.join(this.point,name)))) return null;
		if(!this.fs.isWritable) return null;
		var file = this.fs.File(name);
		return file.exists().then((exist){
		  	if(!exist) throw "File Not Exists";
			return file.appendAsString();
		});
	}

	Future destroyFile(String name){
		if(!this.validatePath(paths.normalize(paths.join(this.point,name)))) return null;
		if(!this.fs.isWritable) return null;
		var file = this.fs.File(name);
		return file.exists().then((exist){
		  if(!exist) throw "File Not Exists";
		  return file.delete();
		});
	}

	Future exists(String name){
		if(!this.validatePath(paths.normalize(paths.join(this.point,name)))) return null;
		var file = this.fs.File(name);
		return file.exists();
	}
}

class WebSocketRequestServer extends WebSocketRequest{
	final options = Hub.createMapDecorator();
	RequestSpecs spec;

	static create(s,c,r,[e]) => new WebSocketRequestServer(s,c,r,e);

	WebSocketRequestServer(s,c,r,[e]): super(s,c,r){
		this.spec = e;
	}

	void headers(tag,value){
		if(!this.isHttp) return;
		this.request.response.headers.add(tag,value);
	}

	void httpSend(dynamic data){
		if(!this.isHttp) return;
		this.request.response.write(data);
		this.endRequest();
	}

	void httpWrite(dynamic data){
		if(!this.isHttp) return;
		this.request.response.write(data);
	}

	void endRequest(){
		this.request.response.close();
	}

	void socketSend(dynamic data){
		if(!this.isSocket) return;
		print('sending to $data');
		this.socket.add(data);
	}

	bool get isHttp => this.socket == null && this.request != null;

	String toString(){
		if(this.request != null) return this.request.uri.path;
	}

}

class StaticRequestHelpers{

	static Function fsTransformer(Function pathCleaner,Function requestCleaner){
		return (r){

			var ast = pathCleaner(r).toString();


			if(_rootReg.hasMatch(ast) || ast == '/'){
				r.options.add('valid',true);
				r.options.add('isRootDirectory',true);
			}else{
				r.options.add('valid',r.spec.validatePath(ast));
				r.options.add('isRootDirectory',r.spec.isRootDirectory(ast));
			}

			r.options.add('realPath',ast);
			r.options.add('originalPath',r.request.uri.path);

			r.options.add('handler',(s,m){

					var future = new Completer(), list = [];

					if(m is Exception){
						future.complete(m);
						return future.future;
					}
					//clean up the paths for return 
					m.on((k){ 
						var cleaned = paths.normalize(k.replaceAll('..','').replaceFirst('\\',''));
						list.add(paths.normalize(requestCleaner(cleaned)));
					});
					//close and complete future
					m.whenClosed((_){ future.complete(list); });

					return future.future;
			});

			return r;
		};
	}

	static dynamic renderFileRequest([Function n,Function socket]){
		return (WebSocketRequestServer r){
			if(r.spec is FileRequestSpecServer && r.isHttp){
				r.spec.readAsString().then((data){
					if(r.isHttp && n != null) return n(r,data);
					if(r.isSocket && socket != null) return socket(r,data);
				});
			};
		};
	}
}

class SocketireServer{
	final subspace = Hub.createMapDecorator();
	final sm.Streamable errors = sm.Streamable.create();
	final sm.Streamable info = sm.Streamable.create();
	final sm.Distributor initd = sm.Distributor.create('initd');
	final options = Hub.createMapDecorator();
	final _alive = Switch.create();
	Function socketHandle,httpHandle;
	Completer done;
	Future serverFuture;
	GuardedFS fs;
	HttpServer s;
	WebSocket socket;
  	
  	static create([addr,port,n,s]) => new SocketireServer(addr,port,n,s);
	
	SocketireServer([String addr,num port,Function sh,Function hh]){
		this.socketHandle = (sh == null ? SocketireRequestHelper.matchRequest(new RegExp(r'^/ws')) : sh);
		this.httpHandle = (hh == null ? (r){ return true; } : hh);
		this.options.add('addr',(addr == null ? '127.0.0.1' : addr));
		this.options.add('port',(port == null ? 3000 : port));
	}

	void initGuardedFS(String path){
		this.fs = GuardedFS.create(paths.normalize(path),true);
	}

	void space(String space,Function matcher){
	  if(this.subspace.has(space)) throw "Namespace $space already in used!";
	  this.subspace.add(space,RequestSpecsServer.create(space,matcher));
	}

	void fsSpace(String space,String path,Function matcher,[bool writa]){
	  if(this.subspace.has(space)) throw "Namespace $space already in used!";
	  this.subspace.add(space,FSRequestSpecServer.create(space,matcher,path,writa));
	}

	void fileSpace(String space,String path,Function matcher){
	  if(this.subspace.has(space)) throw "Namespace $space already in used!";
	  this.subspace.add(space,FileRequestSpecServer.create(this.fs.File(paths.normalize(path)),space,matcher,path));
	}

	RequestSpecsServer spec(String space){
		if(!this.subspace.has(space)) return null;
		return this.subspace.get(space);
	}

	sm.Streamable stream(String space){
		if(!this.subspace.has(space)) return null;
		var stream = this.spec(space);
		return stream.stream;
	}

	sm.Streamable request(String space,RegExp e){
		if(this.subspace.has(space)) return this.stream(space);
		this.space(space,SocketireRequestHelper.matchRequest(e));
		return this.stream(space);
	}

	sm.Streamable requestFS(String space,RegExp e,String path,[bool m]){
		if(this.subspace.has(space)) return this.stream(space);
		this.fsSpace(space,path,SocketireRequestHelper.matchRequest(e),m);
		var stream = this.stream(space);
		return this.stream(space);
	}

	sm.Streamable requestFile(String space,RegExp e,String path){
		if(this.subspace.has(space)) return this.stream(space);
		this.fileSpace(space,path,SocketireRequestHelper.matchRequest(e));
		var stream = this.stream(space);
		return stream;
	}

	sm.Streamable applyFSTransformer(String space,Function pre,Function post){
		var stream = this.stream(space);
		if(stream == null) return null;
		stream.transformer.on(StaticRequestHelpers.fsTransformer(pre,post));
		return stream;
	}

	void render(String space,WebSocketRequestServer r){
		if(!this.subspace.has(space)) return null;
		r.spec = this.spec(space);
		this.stream(space).emit(r);
	}

	SocketireServer ready([Future<HttpServer> s]){
		// runZoned((){
				
			if(this._alive.on()) return this.done.future;

			this.done = new Completer());
			this.serverFuture = (s == null ? HttpServer.bind(this.options.get('addr'),this.options.get('port')) : s);
			this.serverFuture.then((server){
				this.s = server;
				server.listen(this.handleRequest);
				this.initd.emit(this);
				this.done.complete(this);
				this._alive.switchOn();
			},onError:(e){
				this.errors.emit(e);
				this.done.completeError(e);
				this._alive.SwitchOff();
				this.s = null;
			});

		// },onError:(e,s){
		// 	print('gona error out: $e : $s');
		// 	this.errors.emit(e);
		// 	this.s = null;
		// 	this.ready();
		// });

		return this.done.future;
	}

  	void handleRequest(request){
  		if(this.subspace.storage.isEmpty) return;

  		var wsreq = WebSocketRequestServer.create(null,null,request);
  		this.info.emit(wsreq);

  		var handler = this.getMatched(request,(e){

  			wsreq.spec  = e;

	  		if(!!this.socketHandle(request)){
	  			if(e.hasSocket) return;

				WebSocketTransformer.upgrade(request).then((websocket){
            		e.setSocket(websocket,request,(msg,sm,ws,req){
            			wsreq.socket = ws;
            			wsreq.message = msg;
						sm.emit(wsreq);
        			});
				}).catchError((e){
					wsreq.error = e;
					this.errors.emit(wsreq);
				});
				return null;
	  		}

	  		if(!!this.httpHandle(request)){
	  			wsreq.request = request;
	  			return e.stream.emit(wsreq);
	  		}

		},(req){
			this.errors.emit(wsreq);
		});
  	}

  	RequestSpecs getMatched(req,Function n,[Function m]){
  		Hub.eachSyncMap(this.subspace.storage,(e,i,o,fn){
  			if(e.checker(req)) return n(e);
  			fn(false);
		},(o){
			if(m != null) m(req);
		});
  	}

}