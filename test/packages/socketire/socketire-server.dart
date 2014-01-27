library socketire;

import 'dart:io';
import 'dart:async';
import 'package:hub/hub.dart';
import 'package:streamable/streamable.dart' as sm;
import 'package:/guardedfs/guardedfs.dart';

part 'socketire-requester.dart';

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

class FSRequestSpecServer extends RequestSpecsServer{
	final sm.Streamable states = sm.Streamable.create();
	GuardedFS fs;

	static create(s,f,n,w) => new FSRequestSpecServer(s,f,n,w);

	FSRequestSpecServer(String space,Function handle,String path,bool readonly): super(space,handle){
		this.fs = GuardedFS.create(path,readonly);
		this.states.setMax(100);
	}

	void listDirectory([bool recursive]){
		this.fs.directoryListsAsString().then((_){
			this.stream.emit(n);
			this.states.emit({'path':'.','state':true,'method':'listDirectory'});
		});
	}

	void readFile(String name){
		var file = this.fs.File(name);
		file.exists().then((exist){
		  if(!!exist) 
		  file.readAsString().then((data){
		  	this.stream.emit(data);
			this.states.emit({'path':file.path,'state':true,'method':'readFile'});
		  }).catchError((e){
			this.states.emit({'path':file.path,'state':false,'method':'readFile','error': e});
		  });
		});
	}

	void createFile(String name,dynamic data){
		if(!this.fs.isWritable) return this.states.emit({'path':name,'method':'createFile','data':data,'state':false});
		var file = this.fs.File(name);
		file.writeAsString().then((f){
			this.states.emit({'path':file.path,'state':true});
		}).catchError((e){
			this.states.emit({'path':name,'method':'createFile','data':data,'state':false,'error': e});
		});
	}

	void appendFile(String name,dynamic data){
		if(!this.fs.isWritable) return this.states.emit({'path':name,'method':'appendFile','data':data,'state':false});
		var file = this.fs.File(name);
		file.appendAsString().then((f){
			this.states.emit({'path':file.path,'state':true,'method':'appendFile'});
		}).catchError((e){
			this.states.emit({'path':file.path,'method':'appendFile','data':data,'state':false,'error': e});
		});
	}

	void destroyFile(String name){
		if(!this.fs.isWritable) 
			return this.states.emit({'path':name,'method':'destroyFile','data':data,'state':false});
		var file = this.fs.File(name);
		file.exists().then((exist){
		  if(!!exist) 
		  file.delete().then((data){
		  	this.stream.emit(data);
			this.states.emit({'path':file.path,'state':true,'method':'destroyFile'});
		  }).catchError((e){
				this.states.emit({'path':name,'method':'destroyFile','data':data,'state':false,'error': e});
		  });
		});
	}

	void exists(String name){
		var file = this.fs.File(name);
		file.exists().then((exist){
		  if(!!exist) 
		  file.readAsString().then((data){
		  	this.stream.emit({'file':file.path,'exists':true});
			this.states.emit({'path':file.path,'state':true,'method':'exists'});
		  }).catchError((e){
			this.states.emit({'path':file.path,'state':false,'method':'exists','error': e});
		  });
		});
	}
}

class WebSocketRequestServer extends WebSocketRequest{
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

	void endRequest(){
		this.request.response.close();
	}

	void socketSend(dynamic data){
		//if(!this.isSocket) return;
		print('sending socket data: $data');
		this.socket.add(data);
	}

	bool get isHttp => this.socket == null && this.request != null;

}

class SocketireServer{
	final subspace = Hub.createMapDecorator();
	final sm.Streamable errors = sm.Streamable.create();
	final sm.Streamable info = sm.Streamable.create();
	Completer _ready = new Completer();
	Function socketHandle,httpHandle;
	HttpServer s;
	Future serverFuture;
	WebSocket socket;
  	
  	static create(addr,port,n,[s,k]) => new SocketireServer(addr,port,n,s,k);
  	static createFrom(f,n,[h,k]) => new SocketireServer.fromServer(f,n,h,k);
	
	SocketireServer(String addr,num port,Function sh,[Function hh,Function err]){
		this.socketHandle = sh;
		this.httpHandle = (hh == null ? (r){ return true; } : hh);
		this.serverFuture = HttpSever.bind(addr,port);
		this._setup(err);
	}
	
	SocketireServer.fromServer(Future<HttpSever> binder,Function sh,[Function hh,Function err]){
		this.serverFuture = binder;
		this.socketHandle = sh;
		this.httpHandle = (hh == null ? (r){ return true; } : hh);
		this._setup(err);
	}

	void space(String space,Function matcher){
	  if(this.subspace.has(space)) throw "Namespace $space already in used!";
	  this.subspace.add(space,RequestSpecsServer.create(space,matcher));
	}

	void fsSpace(String space,String path,Function matcher,[bool writa]){
	  if(this.subspace.has(space)) throw "Namespace $space already in used!";
	  this.subspace.add(space,FSRequestSpecServer.create(space,matcher,path,writa));
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
		return this.stream(space);
	}
	void render(String space,HttpRequest r){
		if(!this.subspace.has(space)) return null;
		this.stream(space).emit(r);
	}

	void _setup([Function err]){
		this.serverFuture.then((server){
			this.s = server;
			server.listen(this.handleRequest,onError:(e){
				if(err != null) return err(e);
				throw e;
			});
			this._ready.complete(this);
		});
	}

	Future ready() => this._ready.future;

  	void handleRequest(request){
  		if(this.subspace.storage.isEmpty) return;

  		var wsreq = WebSocketRequestServer.create(null,null,request);
  		this.info.emit(wsreq);

  		var handler = this.getMatched(request,(e){

  			print('request: ${request.uri}: $e : ${wsreq} : ${wsreq.spec}');
  			wsreq.spec  = e;

	  		if(!!this.socketHandle(request)){
	  			if(e.hasSocket) return e.closeSocket();

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
	  			return e.stream.emit(wsreq);
	  		}

		},(req){
			this.errors.emit(wsreq);
		});
  	}

  	RequestSpecs getMatched(req,Function n,[Function m]){
  		Hub.eachSyncMap(this.subspace.storage,(e,i,o,fn){
  			print('checker: $e : ${req.uri} : ${e.checker(req)}');
  			if(e.checker(req)) return n(e);
  			fn(false);
		},(o){
			if(m != null) m(req);
		});
  	}

}