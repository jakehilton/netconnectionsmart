/*
<AUTHOR: Jake Hilton, jake@gearsandcogs.com
Copyright (C) 2010, Gears and Cogs.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

VERSION: 0.7.8
DATE: 4/4/2011
ACTIONSCRIPT VERSION: 3.0
DESCRIPTION:
Used to connect quickly through firewalls by trying a shotgun connection apprach with netconnections. 
It does have a few properties like force_tunneling and encrypted that can be set before the connect call is made.
It also has an event that fires to notify the user of a log that was made and is ready for reading.

USAGE:
It's a simple use case really.. just use it as you would the built in NetConnection class. Just specify rtmp as the protocol and let
the class handle the rest whether to use rtmpt or rtmp. In the case of encrypted still only pass in rtmp and it will resolve to rtmpe or rtmpte.
The only caveat is that for netstreams you'd need to pass in a reference to the connection and not the main class.

For example:

var client_obj:Object = new Object();
client_obj.serverMethod = function(e:Object):void
{
trace("server can call this");
}

var snc:NetConnectionSmart = new NetConnectionSmart();
snc.client = client_obj;
snc.encrypted = true; //if this isn't specified it will default to rtmp/rtmpt.. if true it will try rtmpe/rtmpte
snc.connect("rtmp://myserver.com/application");

snc.addEventListener(NetStatusEvent.NET_STATUS,function(e:NetStatusEvent):void
{
trace("connection status: "+e.info.code);
trace(snc.uri);
trace(snc.protocol);
});

var ns:NetStream = new NetStream(snc.connection);

*/

package com.gearsandcogs.utils
{
	import flash.events.AsyncErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.NetConnection;
	import flash.net.Responder;
	import flash.utils.setTimeout;
	
	public class NetConnectionSmart extends EventDispatcher
	{
		public static const INTERMEDIATE_EVT	:String = "NetConnectionEvent";
		public static const VERSION				:String = "NetConnectionSmart v 0.7.8";
		
		private static const RTMP				:String = "rtmp";
		private static const RTMPT				:String = "rtmpt";
		
		public var default_port_only			:Boolean;
		public var debug						:Boolean;
		public var event_msg					:String = "";
		
		private var _nc_types					:Array;
		
		private var _force_tunneling			:Boolean;
		private var _connect_encrypted			:Boolean;
		
		private var _nc_client					:Object;
		
		private var _nc							:PortConnection;
		
		public function NetConnectionSmart()
		{
			if(debug)
				log(VERSION);
			
			_nc_client = new Object();
			initConnectionTypes();
		}
		
		/**
		 * 
		 *public method callable like the netconnection ones 
		 * 
		 */		
		
		public function get connection():NetConnection
		{
			return _nc;
		}
		
		public function call(command:String,responder:Responder=null,...parameters):void
		{
			_nc.call.apply(null,[command,responder].concat(parameters));
		}
		
		public function connect(command:String, ...parameters):void
		{
			var connect_string:String = command.substr(command.indexOf("://")+3);
			var server_string:String = connect_string.substr(0,connect_string.indexOf("/"));
			var app_string:String = connect_string.substr(connect_string.indexOf("/"));
			var encrypted_string:String = _connect_encrypted?"e":"";
			
			initPortConnections();
			
			if(!_force_tunneling){
				for(var i:String in _nc_types){
					if(_nc_types[i].protocol == RTMP)
					{
						if(default_port_only && _nc_types[i].port != "default")
							continue;
						
						var portpass:String = _nc_types[i].port!="default"?":"+_nc_types[i].port:"";
						
						if(debug) 
							log("connecting to: "+_nc_types[i].protocol+encrypted_string+"://"+server_string+portpass+app_string);
						
						_nc_types[i].connection.connect.apply(null,[_nc_types[i].protocol+encrypted_string+"://"+
							server_string+portpass+app_string].concat(parameters));
					}
				}
			}
			
			setTimeout(function():void{
				if(!connected){
					for(var i:String in _nc_types)
					{
						if(_nc_types[i].protocol == RTMPT)
						{
							if(default_port_only && _nc_types[i].port != "default")
								continue;
							
							var portpass:String = _nc_types[i].port!="default"?":"+_nc_types[i].port:"";
							
							if(debug) 
								log("connecting to: "+_nc_types[i].protocol+encrypted_string+"://"+server_string+portpass+app_string);
							
							_nc_types[i].connection.connect.apply(null,[_nc_types[i].protocol+encrypted_string+"://"+
								server_string+portpass+app_string].concat(parameters));
						}
					}
					
				}
			},_force_tunneling?10:1000);
		}
		
		public function get connected():Boolean
		{
			try{
				return _nc.connected;
			} catch(e:Error){}
			
			return false;
		}
		
		public function set client(obj:Object):void
		{
			_nc_client = obj;
		}
		
		public function close():void
		{
			if(_nc)
				_nc.close();
		}
		
		public function get objectEncoding():uint
		{
			return _nc.objectEncoding;
		}
		
		public function set objectEncoding(encoding:uint):void
		{
			_nc.objectEncoding = encoding;
		}
		
		public function get protocol():String
		{
			return _nc.uri.substr(0,_nc.uri.indexOf("://"));
		}
		
		public function get proxyType():String
		{
			return _nc.proxyType;
		}
		
		public function get connectedProxyType():String
		{
			return _nc.connectedProxyType;
		}
		
		public function get uri():String
		{
			return _nc.uri;
		}
		
		public function get usingTLS():Boolean
		{
			return _nc.usingTLS;
		}
		
		public function get force_tunneling():Boolean
		{
			return _force_tunneling;
		}
		
		public function set force_tunneling(tunnel:Boolean):void
		{
			_force_tunneling = tunnel;
		}
		
		public function get encrypted():Boolean
		{
			return _connect_encrypted;
		}
		
		public function set encrypted(encrypted_connect:Boolean):void
		{
			_connect_encrypted = encrypted_connect;
		}
		
		/**
		 * 
		 * private methods used to push things up the stack for listeners
		 * and to manage net connections
		 * 
		 */	
		
		private function acceptNc(portConnection:PortConnection):void
		{
			_nc = portConnection;
			
			_nc.removeEventListener(PortConnection.STATUS_UPDATE,checkNetStatus);
			_nc.removeStatusHandler();
			
			_nc.addEventListener(AsyncErrorEvent.ASYNC_ERROR,handleAsyncError);
			_nc.addEventListener(IOErrorEvent.IO_ERROR,handleIoError);
			_nc.addEventListener(NetStatusEvent.NET_STATUS,handleNetStatus);
			_nc.addEventListener(SecurityErrorEvent.SECURITY_ERROR,handleSecurityError);
			
			_nc.client = _nc_client;
			
			closeExtraNc();
		}
		
		private function closeExtraNc():void
		{
			for each(var n:Object in _nc_types){
				var portConnection:PortConnection = n.connection as PortConnection;
				if(portConnection && portConnection != _nc)
					closeDownNc(portConnection);
			}
		}
		
		private function closeDownNc(pc:PortConnection):void
		{
			if(debug)
				trace("Closing down a nc: "+pc.label);
			
			pc.removeEventListener(PortConnection.STATUS_UPDATE,checkNetStatus);
			pc.addEventListener(NetStatusEvent.NET_STATUS,nullHandleNetStatus);
			pc.close();
			
			//cleanup listener
			pc.removeStatusHandler();
		}
		
		private function initConnectionTypes():void
		{
			_nc_types = new Array();
			_nc_types.push({protocol:RTMP,port:"1935"});
			_nc_types.push({protocol:RTMP,port:"443"});
			_nc_types.push({protocol:RTMP,port:"80"});
			_nc_types.push({protocol:RTMP,port:"default"});
			
			_nc_types.push({protocol:RTMPT,port:"1935"});
			_nc_types.push({protocol:RTMPT,port:"443"});
			_nc_types.push({protocol:RTMPT,port:"80"});
			_nc_types.push({protocol:RTMPT,port:"default"});
		}
		
		private function initPortConnections():void
		{
			var encrypted_string:String = encrypted?"Encrypted ":""; 
			for(var i:String in _nc_types)
			{
				var port_label:String = encrypted_string+" "+_nc_types[i].protocol+" "+_nc_types[i].port;
				var curr_pc:PortConnection = new PortConnection(parseInt(i),port_label,debug);
				
				if(force_tunneling && _nc_types[i].protocol == RTMP)
					curr_pc.status = new NetStatusEvent("skipped");
				
				curr_pc.client = _nc_client;
				curr_pc.addEventListener(PortConnection.STATUS_UPDATE,checkNetStatus);
				_nc_types[i].connection = curr_pc;
			}
		}
		
		private function checkNetStatus(e:Event):void
		{
			var target_connection:PortConnection = e.target as PortConnection;
			log(target_connection.label+": "+target_connection.status.info.code);
			
			var status_count:uint;
			var rejected_connection:PortConnection;
			
			for each(var i:Object in _nc_types)
			{
				var curr_connection:PortConnection = i.connection as PortConnection;
				
				if(curr_connection.status)
					status_count++;
				
				if(!connected && curr_connection.connected)
				{
					acceptNc(curr_connection);
					dispatchEvent(curr_connection.status);
					break;
				} else if(curr_connection.rejected){
					rejected_connection = curr_connection;
				}
			}
			
			//if no success at all return the first rejected message or
			//return the status of the last connection in the array
			if(!connected && status_count == _nc_types.length)
			{
				if(!rejected_connection)
					dispatchEvent(_nc_types[_nc_types.length-1].connection.status);
				else
					dispatchEvent(rejected_connection.status);
			}
			
		}
		
		private function handleAsyncError(e:AsyncErrorEvent):void
		{
			if(debug) 
				log(e.error.toString());
			dispatchEvent(e);
		}
		
		private function handleIoError(e:IOErrorEvent):void
		{
			if(debug) 
				log(e.text);
			dispatchEvent(e);
		}
		
		private function nullHandleNetStatus(e:NetStatusEvent):void
		{
			if(debug) 
				log("null handler: "+e.info.code);
		}
		
		private function handleNetStatus(e:NetStatusEvent):void
		{
			if(debug) 
				log(e.info.code);
			dispatchEvent(e);
		}
		
		private function handleSecurityError(e:SecurityErrorEvent):void
		{
			if(debug) 
				log(e.text);
			dispatchEvent(e);
		}
		
		private function log(msg:String):void
		{
			if(debug) 
				trace("NetConnectionSmart: "+msg);
			event_msg = msg;
			dispatchEvent(new Event(INTERMEDIATE_EVT));
		}
		
	}
}

import flash.events.Event;
import flash.events.NetStatusEvent;
import flash.net.NetConnection;

class PortConnection extends NetConnection
{
	public static const STATUS_UPDATE	:String = "status_update";
	
	public var debug					:Boolean;
	public var id						:int;
	public var status					:NetStatusEvent;
	public var label					:String;
	
	public function PortConnection(id:int,label:String,debug:Boolean=false)
	{
		super();
		this.debug = debug;
		this.id = id;
		this.label = label;
		addStatusHandler();
	}
	
	public function addStatusHandler():void
	{
		addEventListener(NetStatusEvent.NET_STATUS,handleNetStatus);
	}
	
	private function handleNetStatus(e:NetStatusEvent):void
	{
		//if rejected connection came in we want to preserve that message
		if(!status || (status && status.info.code != "NetConnection.Connect.Rejected")){
			if(debug) 
				trace("PortConnection: "+e.info.code);
			status = e;
			dispatchEvent(new Event(STATUS_UPDATE));
		}
	}
	
	public function removeStatusHandler():void
	{
		removeEventListener(NetStatusEvent.NET_STATUS,handleNetStatus);
	}
	
	public function onBWDone():void
	{
		//don't do anything
	}
	
	public function getProtocol():String
	{
		return uri.substr(0,uri.indexOf("://"));
	}
	
	public function get rejected():Boolean
	{
		try{
			return status.info.code == "NetConnection.Connect.Rejected";
		}catch(e:Error){}
		
		return false;
	}
}