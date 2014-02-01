library socketire;

import 'dart:async';
import 'dart:html';
import 'package:hub/hub.dart';
import 'package:streamable/streamable.dart' as sm;

part 'helpers.dart';

class RequestSpecsClient extends RequestSpecs{
	var whenOpen = Hub.createDistributor('whenOpen');
	var whenSocketClosed = Hub.createDistributor('whenSocketClosed');
	var routeSets = Hub.createMapDecorator();

	static create(s,f) => new RequestSpecsClient(s,f);

	RequestSpecsClient(String s,[Function n]): super(s,Hub.switchUnless(n,(m){ return true; })){
		this.route('*');
	}

	void setSocket(socket){
		this._socket = socket;
		this._socket.onMessage.listen((msg){
			if(!this.checker(msg)) return;
			this.stream.emit(msg);
		});
		this.whenOpen.emit(this);
	}

	void sendTo(String r,dynamic m){
		this.route(r).emit(m);
	}

	void send(data){
		if(!this.hasSocket) return;
		this.socket.send(data);
	}

	void closeSocket(){
		this.whenSocketClosed.emit(this);
		super.closeSocket();
	}

	Stream route(String r){
		if(this.routeSets.has(r)) return this.routeSets.get(r);
		this.routeSets.add(r,sm.Streamable.create());
	}

	void close(){
		super.close();
		this.routeSets.onAll((e){ e.close(); });
		this.routeSets.flush();
	}
}

class SocketireClient{
	final sm.Streamable errors = sm.Streamable.create();
	bool _reboot  = false;
	int retrySeconds = 2;
	var subspace,db, rebooter;

	static create() => new SocketireClient();

	SocketireClient(){
		this.subspace = Hub.createMapDecorator();
	}

	void enableReconnect(){
		this._reboot = true;
	}

	void disableReconnect(){
		this._reboot = false;
	}

	bool get canReboot => !!this._reboot;

	dynamic space(String nm,String space,[Function matcher]){
	  if(this.subspace.has(nm)) return this.subspace.get(nm);
	  var sub = RequestSpecsClient.create(space,matcher);
	  this.subspace.add(nm,sub);
	  return sub;
	}

	void send(String space,dynamic data){
		if(!this.subspace.has(space)) return;
		this.subspace.get(space).send(data);
	}

	dynamic spec(String space){
		if(!this.subspace.has(space)) return null;
		return this.subspace.get(space);
	}

	dynamic stream(String space){
		if(!this.subspace.has(space)) return null;
		return this.subspace.get(space).stream;
	}

	void connect(String space){
		if(!this.subspace.has(space)) return;

		var sub = this.subspace.get(space);

		if(sub.hasSocket) sub.closeSocket();


		var ws = new WebSocket(sub.namespace);
		var retry = this.retrySeconds;

		ws.onOpen.listen((e){
			retry = 2;
			sub.setSocket(ws);
		});

		ws.onClose.listen((e){
			if(!this.canReboot){
				return sub.closeSocket();
			}
			retry *= 2;
			new Timer(new Duration(seconds: retry),() => this.connect(space));
		});

		ws.onError.listen((e){
			this.errors.emit({ 'target': space,'error': e});
		});

	}

	void close(){
		this.retrySeconds = 2;
		this.subspace.onAll((k,v){ v.close(); });
		this.subspace.flush();
		this.errors.close();
	}
}