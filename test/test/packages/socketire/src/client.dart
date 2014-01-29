library socketire;

import 'dart:async';
import 'dart:html';
import 'package:hub/hub.dart';
import 'package:streamable/streamable.dart' as sm;

part 'helpers.dart';

class RequestSpecsClient extends RequestSpecs{
	var whenOpen = Hub.createDistributor('whenOpen');
	var whenSocketClosed = Hub.createDistributor('whenSocketClosed');


	static create(s,f) => new RequestSpecsClient(s,f);

	RequestSpecsClient(String s,Function n): super(s,n);

	void setSocket(socket,Function n){
		this._socket = socket;
		this._socket.onMessage.listen((msg){
			print('word: $msg : ${this.checker(msg)}');
			if(!this.checker(msg)) return null;
			n(msg,this._socket,this);
		});
		this.whenOpen.emit(this);
	}

	void send(data){
		if(!this.hasSocket) return;
		this.socket.send(data);
	}

	void closeSocket(){
		this.whenSocketClosed.emit(this);
		super.closeSocket();
	}

}

class WebSocketRequestClient extends WebSocketRequest{

	static create(s,c) => new WebSocketRequestClient(s,c);

	WebSocketRequestClient(s,m): super(s,m,null);

	void send(data){
		if(!this.isSocket) return;
		this.socket.send(data);
	}
}

class SocketireClient{
	final sm.Streamable errors = sm.Streamable.create();
	bool _reboot  = false;
	String root;
	int retrySeconds = 2;
	var subspace,db, rebooter;

	static create(m) => new SocketireClient(m);

	SocketireClient(String m){
		this.root = m;
		this.subspace = Hub.createMapDecorator();
	}

	void enableReconnect(){
		this._reboot = true;
	}

	void disableReconnect(){
		this._reboot = false;
	}

	bool get canReboot => !!this._reboot;

	void send(String space,dynamic data){
		if(!this.subspace.has(space)) return;
		this.subspace.get(space).send(data);
	}

	dynamic spec(String space){
		if(!this.subspace.has(space)) return null;
		return this.subspace.get(space);
	}

	void connect(String space){
		if(!this.subspace.has(space)) return;

		print('initing');
		var sub = this.subspace.get(space);
		var full = this.root + '/' + space;

		if(sub.hasSocket) sub.closeSocket();


		var ws = new WebSocket(full);
		var retry = this.retrySeconds;

		var wsreq = WebSocketRequestClient.create(ws,null);

		print(ws.on);

		ws.onOpen.listen((e){
			retry = 2;
			sub.setSocket(ws,(msg,socket,req){
				wsreq.socket = socket;
				wsreq.message = msg;
				req.stream.emit(wsreq);
			});
		});

		ws.onClose.listen((e){
			if(!this.canReboot){
				return sub.closeSocket();
			}
			retry *= 2;
			new Timer(new Duration(seconds: retry),() => this.connect(space));
		});

		ws.onError.listen((e){
			wsreq.error = e;
			this.errors.emit(wsreq);
		});

	}

	dynamic space(String space,Function matcher){
	  if(this.subspace.has(space)) return this.subspace.get(space);
	  var sub = RequestSpecsClient.create(space,matcher);
	  this.subspace.add(space,sub);
	  return sub;
	}

	sm.Streamable stream(String space){
		if(!this.subspace.has(space)) return null;
		return this.subspace.get(space).stream;
	}

	void close(){
		this.retrySeconds = 2;
		this.subspace.onAll((k,v){ v.close(); });
		this.subspace.flush();
		this.errors.close();
	}
}