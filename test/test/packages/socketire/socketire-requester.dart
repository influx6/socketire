part of socketire;

class SocketireRequestHelper{

	static Function matchRequest(RegExp match,[Function run]){
		return (HttpRequest r){
			if(run != null) return run(r,match);
			return match.hasMatch(r.uri.path);
		};
	}

}

class WebSocketRequest{
	WebSocket socket;
	dynamic message;
	dynamic request;
	dynamic error;

	static create(s,c,r) => new WebSocketRequest(s,c,r);

	WebSocketRequest(s,c,r){
		this.socket = s;
		this.message = c;
		this.request = r;
	}

	bool get isSocket => this.socket != null;
	bool get isHttp => this.request != null;

}

class RequestSpecs{
	String _namespace;
	Function _checker;
	sm.Streamable _stream;
	WebSocket _socket;


	RequestSpecs(String space,Function handle){
		this._namespace = space;
		this._stream = sm.Streamable.create();
		this._checker = handle;
		this._stream.whenClosed((){
			if(this._socket != null) this._socket.close();
		});

		this._stream.transformer.on((n){ return n; });
	}


	Function get checker => this._checker;

	sm.Streamable get stream => this._stream;

	String get namespace => this._namespace;

	bool get hasSocket => this._socket != null;
	
	WebSocket get socket => this._socket;

	void setSocket();
	
	void closeSocket(){
		this.socket.close();
		this._socket = null;
	}
	
	void close(){
		this.closeSocket();
		this.stream.close();
	}
}

