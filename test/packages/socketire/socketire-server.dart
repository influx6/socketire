library socketire;

import 'dart:io';
import 'dart:async';


class Socketire{
	final Map subspace = new Map();
	HttpServer s;
	WebSocket socket
	Completer ready;

	Socketire(this.s,[Function err]){
		this.s.listen((request){
			WebSocketTransformer.upgrade(request).then((webscoket){
				this.socket = webscoket;
				this.ready.complete(this.socket);
			})
		},onError:(e){
			if(err != null) return err(e);
			throw e;
		});
	}

	Future ready(){
		return	this._ready.future.then((_){ return this; });
	}

	Socketire space(String space){
		if(this.subspace.containsKey(space)) throw "Space name $space already in use!";
	}


}