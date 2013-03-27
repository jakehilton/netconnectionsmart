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

VERSION: 0.9.20
DATE: 2/28/2013
ACTIONSCRIPT VERSION: 3.0
DESCRIPTION:
A replacement class for the standard NetConnection actionscript class. This easily enables multiple port attempts to resolve at the best functioning port.

Used to connect quickly through firewalls by trying a NetConnection via a shotgun connection approach or an incremental connection approach.

Possible protocol attempts: rtmp,rtmpt,rtmpe,rtmpte,rtmps.

It does have a few properties listed below that can be set before the connect call is made.

append_guid: a boolean to enable a unique GUID be placed at the end of the parameters argument passed into the connect method.  
This can be used to identify which connection requests are coming from the same client and that can be ignored if one is already being processed.
recreate_guid: a boolean to enable the recreation of the GUID each time the main connect method is called. By default this is false.
auto_reconnect: a boolean to enable or dispable automatic reconnect attempts. By default this is set to false.
connection_rate: only applicable if using a non-shotgun approach. Sets the rate that connections are tried. By default this is 200ms
debug: if you want to see debug messages via your trace panel
enctyped: used if you want to force the use of an encrypted connection (rtmp(t)e)
force_tunneling: used if you don't ever want to attempt rtmp connections
reconnect_count_limit: specify the max amount of reconnect attempts are made. Default is 10.
shotgun_connect: a boolean to enable or disable the shotgun approach. By default it is enabled.
portArray: an array containing ports in the order they should be tried. By default is it [443,80,1935]

It has an event,MSG_EVT, that fires to notify the user of an event in the class.

If you are experiencing issues with proxies you can try setting the proxyType="best" as this will attempt to use a different connect method if normal attempts fail.

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

var ncs:NetConnectionSmart = new NetConnectionSmart();
ncs.client = client_obj;
ncs.encrypted = true; //if this isn't specified it will default to rtmp/rtmpt.. if true it will try rtmpe/rtmpte
ncs.connect("rtmp://myserver.com/application");

ncs.addEventListener(NetStatusEvent.NET_STATUS,function(e:NetStatusEvent):void
{
trace("connection status: "+e.info.code);
trace(ncs.uri);
trace(ncs.protocol);
});

var ns:NetStream = new NetStream(ncs.connection);

*/

package com.gearsandcogs.utils
{
	import flash.events.AsyncErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.NetConnection;
	import flash.net.ObjectEncoding;
	import flash.net.Responder;
	import flash.utils.Timer;
	
	public class NetConnectionSmart extends EventDispatcher
	{
		public static const MSG_EVT								:String = "NetConnectionSmartMsgEvent";
		public static const VERSION								:String = "NetConnectionSmart v 0.9.20";
		
		public static const NETCONNECTION_CONNECT_CLOSED		:String = "NetConnection.Connect.Closed";
		public static const NETCONNECTION_CONNECT_FAILED		:String = "NetConnection.Connect.Failed";
		public static const NETCONNECTION_CONNECT_REJECTED		:String = "NetConnection.Connect.Rejected";
		public static const NETCONNECTION_CONNECT_SUCCESS		:String = "NetConnection.Connect.Success";
		
		public static const NETCONNECTION_RECONNECT_FAILED		:String = "NetConnection.Reconnect.Failed";
		public static const NETCONNECTION_RECONNECT_INIT		:String = "NetConnection.Reconnect.Init";
		
		private static const RTMP								:String = "rtmp";
		private static const RTMPT								:String = "rtmpt";
		
		public var append_guid									:Boolean;
		public var auto_reconnect								:Boolean;
		public var default_port_only							:Boolean;
		public var debug										:Boolean;
		public var encrypted									:Boolean;
		public var force_tunneling								:Boolean;
		public var recreate_guid								:Boolean;
		public var secure										:Boolean;
		public var sequential_connect							:Boolean;
		public var shotgun_connect								:Boolean = true;
		
		public var connection_rate								:uint = 200;
		public var reconnect_count_limit						:uint = 10;

		private var _connect_params								:Array;
		private var _connect_params_init						:Array;
		private var _ncTypes									:Vector.<NetConnectionType>;
		private var _portArray									:Array = [443,80,1935];
		
		private var _initial_connect_run						:Boolean;
		private var _is_connecting								:Boolean;
		private var _was_connected								:Boolean;
		
		private var _nc_client									:Object;
		
		private var _nc											:PortConnection;
		
		private var _app_string									:String;
		private var _connect_string_init						:String;
		private var _encrypted_secure_string					:String;
		private var _guid										:String;
		private var _proxy_type									:String = "none";
		private var _server_string								:String;
		
		private var _connect_timer								:Timer;
		
		private var _connection_attempt_count					:uint;
		private var _object_encoding							:uint = ObjectEncoding.AMF3;
		private var _reconnect_count							:uint;
		
		public function NetConnectionSmart()
		{
			_nc_client = new Object();
			_guid = GUID.create();
			initConnectionTypes();
		}
		
		/**
		 * 
		 *public functions callable like the netconnection ones
		 *
		 */		
		
		public function call(command:String,responder:Responder=null,...parameters):void
		{
			if(!_nc || !_nc.connected)
				throw(new Error("NetConnection must be connected in order to make a call on it."));
				
			_nc.call.apply(null,[command,responder].concat(parameters));
		}
		
		public function connect(command:String, ...parameters):void
		{
			if(debug)
				log(VERSION);
			
			if(_is_connecting || connected)
				return;
			
			_is_connecting = true;
			
			//strip rtmp variants
			_connect_string_init = command.indexOf("://")>-1?command.substring(command.indexOf("://")+3):command;

			//strip port declaration
			if(_connect_string_init.indexOf(":")>-1)
			{
				var split_connect:Array = _connect_string_init.split(":");
				_connect_string_init = split_connect[0]+split_connect[1].substring(split_connect[1].indexOf("/"));
			}
			
			//setting very low connection rate but helps to avoid race conditions serverside
			if(shotgun_connect)
				connection_rate = 100;
			
			//create new guid
			if(recreate_guid && _initial_connect_run)
				_guid = GUID.create();
			
			_connect_params_init = parameters;
			_connect_params = append_guid?parameters.concat(_guid):parameters;
			_server_string = _connect_string_init.substring(0,_connect_string_init.indexOf("/"));
			_app_string = _connect_string_init.substring(_connect_string_init.indexOf("/"));
			_encrypted_secure_string = encrypted?"e":secure?"s":"";
			_initial_connect_run = true;
			
			if(_server_string == "" || _app_string.length<2)
				throw(new Error("Invalid application path. Need server and application name"));
			
			if(_encrypted_secure_string=="s" && force_tunneling)
				throw(new Error("Secure connections cannot run over rtmpt. Either turn off force tunnelling or the secure flag."));
			
			if(sequential_connect)
				initConnection();
			else
				initializeTimers();
		}
		
		public function set client(obj:Object):void
		{
			_nc_client = obj;
		}
		
		public function get connected():Boolean
		{
			try{
				return _nc.connected;
			} catch(e:Error){}
			
			return false;
		}
		
		public function get connection():NetConnection
		{
			return _nc;
		}
		
		public function close():void
		{
			if(!_nc)
				return;
			
			_was_connected = false;
			_nc.close();
			
			_nc = null;
			closeExtraNc();
		}
		
		public function get connectParams():Array
		{
			return _connect_params_init;
		}
		
		public function set connectParams(paramArray:Array):void
		{
			_connect_params_init = paramArray;
		}
		
		public function get guid():String
		{
			return _guid;
		}
		
		public function get objectEncoding():uint
		{
			return _nc?_nc.objectEncoding:_object_encoding;
		}
		
		public function set objectEncoding(encoding:uint):void
		{
			_object_encoding = encoding;
			if(_nc)
				_nc.objectEncoding = encoding;
		}
		
		public function get protocol():String
		{
			return _nc.uri.substring(0,_nc.uri.indexOf("://"));
		}
		
		public function get proxyType():String
		{
			return _nc.proxyType;
		}
		
		public function set proxyType(type:String):void
		{
			_proxy_type = type;
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
		
		public function get portArray():Array
		{
			return _portArray;
		}
		
		public function set portArray(portArray:Array):void
		{
			_portArray = portArray;
			initConnectionTypes();
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
			_nc.removeHandlers();
			
			_nc.addEventListener(AsyncErrorEvent.ASYNC_ERROR,handleAsyncError);
			_nc.addEventListener(IOErrorEvent.IO_ERROR,handleIoError);
			_nc.addEventListener(NetStatusEvent.NET_STATUS,handleNetStatus);
			_nc.addEventListener(SecurityErrorEvent.SECURITY_ERROR,handleSecurityError);
			
			_nc.client = _nc_client;
			
			try {
				_connect_timer.stop();
			}catch(e:Error){}
			
			closeExtraNc();
		}
		
		private function closeExtraNc():void
		{
			for each(var n:NetConnectionType in _ncTypes){
				var portConnection:PortConnection = n.connection;
				if(portConnection && portConnection != _nc)
				{
					closeDownNc(portConnection);
					n.connection = null;
				}
			}
		}
		
		private function closeDownNc(pc:PortConnection):void
		{
			if(debug)
				log("Closing down NetConnection: "+pc.label);
			
			pc.removeEventListener(PortConnection.STATUS_UPDATE,checkNetStatus);
			pc.addEventListener(NetStatusEvent.NET_STATUS,nullHandleNetStatus);
			pc.close();
			
			//cleanup listener
			pc.removeHandlers();
		}
		
		/**
		 * 
		 * @param netconnection
		 * @param protocol
		 * @param port
		 * @param parameters
		 * 
		 */		
		
		private function processConnection(connection:NetConnection,protocol:String,port:String, parameters:Array):void
		{
			if(default_port_only && port != "default")
				return;
			
			var portpass:String = port!="default"?":"+port:"";
			
			if(debug) 
				log("connecting to: "+protocol+_encrypted_secure_string+"://"+_server_string+portpass+_app_string);
			
			connection.connect.apply(null,[protocol+_encrypted_secure_string+"://"+
				_server_string+portpass+_app_string].concat(parameters));
		}
		
		private function initConnectionTypes():void
		{
			_ncTypes = new Vector.<NetConnectionType>();
			for each(var r:String in _portArray)
			{
				_ncTypes.unshift(new NetConnectionType(RTMP,r));
				_ncTypes.push(new NetConnectionType(RTMPT,r))
			}
		}
		
		private function initPortConnection(nc_num:uint):NetConnectionType
		{
			var encrypted_secure_identifier:String = encrypted?"Encrypted/Secure ":" ";
			
			var curr_nct:NetConnectionType = _ncTypes[nc_num];
			var port_label:String = encrypted_secure_identifier+curr_nct.protocol+" "+curr_nct.port;
			var curr_pc:PortConnection = new PortConnection(nc_num,port_label,debug);
			
			curr_pc.objectEncoding = _object_encoding;
			curr_pc.proxyType = _proxy_type;
			
			if( (force_tunneling && curr_nct.protocol == RTMP) || (secure && curr_nct.protocol == RTMPT) )
				curr_pc.status = new NetStatusEvent("skipped");
			
			curr_pc.client = _nc_client;
			curr_pc.addEventListener(PortConnection.STATUS_UPDATE,checkNetStatus);
			curr_nct.connection = curr_pc;
			
			return curr_nct;
		}
		
		private function initializeTimers():void
		{
			if(debug)
				log("Connecting at a rate of: "+connection_rate);
			
			_connect_timer = new Timer(connection_rate);
			_connect_timer.addEventListener(TimerEvent.TIMER,function(e:TimerEvent):void
			{
				initConnection(_connect_timer.currentCount-1);
			});
			
			_connect_timer.start();
		}
		
		private function initConnection(connect_count:uint=0):void
		{
			_connection_attempt_count = force_tunneling?connect_count+portArray.length:connect_count;
			var curr_nct:NetConnectionType = initPortConnection(_connection_attempt_count);
			
			if(!curr_nct.connection.status || curr_nct.connection.status.type != "skipped")
				processConnection(curr_nct.connection,curr_nct.protocol,curr_nct.port,_connect_params);
			
			//all connection attempts have been tried
			if(_connect_timer && _connection_attempt_count == _ncTypes.length-1)
				_connect_timer.stop();
		}
		
		private function checkNetStatus(e:Event):void
		{
			var target_connection:PortConnection = e.target as PortConnection;
			
			if(debug)
				log(target_connection.label+": "+target_connection.status.info.code);
			
			var status_count:uint;
			var rejected_connection:PortConnection;
			
			for each(var i:NetConnectionType in _ncTypes)
			{
				var curr_connection:PortConnection = i.connection;
				
				if(!curr_connection)
					continue;
				
				if(curr_connection.status)
					status_count++;
				
				if(!connected && curr_connection.connected)
				{
					acceptNc(curr_connection);
					handleNetStatus(curr_connection.status);
					_is_connecting = false;
					_was_connected = true;
					_reconnect_count = 0;
					_connection_attempt_count = 0;
					return;
				} else if(!rejected_connection && curr_connection.rejected)
					rejected_connection = curr_connection;
			}
			
			//if no success at all return the first rejected message or
			//return the status of the first connection in the array
			if(!connected && status_count == _ncTypes.length)
			{
				_is_connecting = false;

				if(!rejected_connection)
					handleNetStatus(_ncTypes[_ncTypes.length-1].connection.status);
				else
					handleNetStatus(rejected_connection.status);
			} else if(sequential_connect)
			{
				initConnection(++_connection_attempt_count);
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
			if(debug && e.info && e.info.code) 
				log(e.info.code);
			
			dispatchEvent(e);
			
			if(!auto_reconnect || !_was_connected || (e.info.code != "NetConnection.Connect.Closed" && e.info.code != "NetConnection.Connect.Failed"))
				return;
			
			if(_reconnect_count<reconnect_count_limit)
			{
				if(debug)
					log("attempting to reconnect");
				
				e.info.code = NETCONNECTION_RECONNECT_INIT;
				e.info.level = "status";
				connect.apply(null,[_connect_string_init].concat(_connect_params_init));
				_reconnect_count++;
			} 
			else
			{
				if(debug)
					log("reconnect limit reached");
				
				e.info.code = NETCONNECTION_RECONNECT_FAILED;
				_reconnect_count = 0;
			}
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
			dispatchEvent(new MsgEvent(MSG_EVT,false,false,msg));
		}
		
	}
}

import flash.events.AsyncErrorEvent;
import flash.events.Event;
import flash.events.NetStatusEvent;
import flash.net.NetConnection;

//custom port connection class to wrap netconnection
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
		addHandlers();
	}
	
	public function addHandlers():void
	{
		addEventListener(AsyncErrorEvent.ASYNC_ERROR,handleAsyncError);
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
	
	private function handleAsyncError(e:AsyncErrorEvent):void
	{
		if(debug)
			trace("PortConnection: "+e.toString());
	}
	
	public function removeHandlers():void
	{
		removeEventListener(AsyncErrorEvent.ASYNC_ERROR,handleAsyncError);
		removeEventListener(NetStatusEvent.NET_STATUS,handleNetStatus);
	}
	
	public function onBWDone():void
	{
		//don't do anything
	}
	
	public function getProtocol():String
	{
		return uri.substring(0,uri.indexOf("://"));
	}
	
	public function get rejected():Boolean
	{
		try{
			return status.info.code == "NetConnection.Connect.Rejected";
		}catch(e:Error){}
		
		return false;
	}
}

class NetConnectionType
{
	public var connection		:PortConnection;
	public var port				:String;
	public var protocol			:String;
	
	public function NetConnectionType(protocol:String, port:String)
	{
		this.port = port;
		this.protocol = protocol;
	}
}