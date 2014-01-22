library socketire;

import 'dart:io';
import 'dart:async';
import 'package:hub/hub.dart';
import 'package:streamable/streamable.dart' as sm;

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

class WebSocketRequestServer extends WebSocketRequest{

	static create(s,c,r) => new WebSocketRequestServer(s,c,r);

	WebSocketRequestServer(s,c,r): super(s,c,r);

	void headers(tag,value){
		if(!this.isHttp) return;
		this.request.response.headers.add(tag,value);
	}

	void httpSend(dynamic data){
		if(!this.isHttp) return;
		this.request.response.write(data);
		this.request.response.close();
	}

	void socketSend(dynamic data){
		//if(!this.isSocket) return;
		print('sending socket data: $data');
		this.socket.add(data);
	}

	bool get isHttp => this.socket == null && this.request != null;

}


class Socketire{
	final subspace = Hub.createMapDecorator();
	final sm.Streamable errors = sm.Streamable.create();
	final sm.Streamable info = sm.Streamable.create();
	Completer _ready = new Completer();
	Function socketHandle,httpHandle;
	HttpServer s;
	Future serverFuture;
	WebSocket socket;
  	
  	static create(addr,port,n,[s,k]) => new Socketire(addr,port,n,s,k);
  	static createFrom(f,n,[h,k]) => new Socketire.fromServer(f,n,h,k);
	
	Socketire(String addr,num port,Function sh,[Function hh,Function err]){
		this.socketHandle = sh;
		this.httpHandle = (hh == null ? (r){ return true; } : hh);
		this.serverFuture = HttpSever.bind(addr,port);
		this._setup(err);
	}
	
	Socketire.fromServer(Future<HttpSever> binder,Function sh,[Function hh,Function err]){
		this.serverFuture = binder;
		this.socketHandle = sh;
		this.httpHandle = (hh == null ? (r){ return true; } : hh);
		this._setup(err);
	}

	void space(String space,Function matcher){
	  if(this.subspace.has(space)) throw "Namespace $space already in used!";
	  this.subspace.add(space,RequestSpecsServer.create(space,matcher));
	}

	RequestSpecsServer spec(String space){
		if(!this.subspace.has(space)) return null;
		return this.subspace.get(space);
	}

	Streamable stream(String space){
		if(!this.subspace.has(space)) return null;
		var stream = this.spec(space);
		return stream.stream;
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

	  		if(!!this.socketHandle(request)){
	  			if(e.hasSocket) return e.closeSocket();

				WebSocketTransformer.upgrade(request).then((websocket){
					print('generated: $websocket');
            		e.setSocket(websocket,request,(msg,sm,ws,req){
            			print('emiting!');
            			wsreq.socket = ws;
            			wsreq.message = msg;
						sm.emit(wsreq);
        			});
				}).catchError((e){
					wsreq.error = e;
					this.errors.emit(wsreq);
				});
				return;
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
  			if(e.checker(req)) return n(e);
  			fn(false);
		},(o){
			if(m != null) m(req);
		});
  	}

}