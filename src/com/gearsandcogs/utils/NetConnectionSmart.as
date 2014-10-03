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

 VERSION: 1.9.0
 DATE: 09/26/2014
 ACTIONSCRIPT VERSION: 3.0
 DESCRIPTION:
 A replacement class for the standard NetConnection actionscript class. This easily enables multiple port attempts to resolve at the best functioning port and protocol.

 Used to connect quickly through firewalls by trying a NetConnection via a shotgun connection approach or an incremental connection approach.

 Possible protocol attempts: rtmp,rtmpt,rtmpe,rtmpte,rtmps, and rtmfp.

 It does have a few properties listed below that can be set before the connect call is made.

 append_guid: a boolean to enable a unique GUID be placed at the end of the parameters argument passed into the connect method.
 This can be used to identify which connection requests are coming from the same client and that can be ignored if one is already being processed.
 recreate_guid: a boolean to enable the recreation of the GUID each time the main connect method is called. By default this is false.
 auto_reconnect: a boolean to enable or disable automatic reconnect attempts. By default this is set to false.
 connection_rate: only applicable if using a non-shotgun approach. Sets the rate that connections are tried. By default this is 200ms
 connection_timeout: the number of seconds to wait for a connection to succeed before it's deemed faulty.
 debug: if you want to see debug messages via your trace panel
 enable_rtmfp: puts rtmfp into the list of attempted protocols. By default this is set to false because it can cause slow timeouts when used with sequential connect
 encrypted: used if you want to force the use of an encrypted connection (rtmp(t)e)
 secure: used if you want to force the use of an SSL connection (rtmps). Not compatible with force_tunneling.
 force_tunneling: used if you don't ever want to attempt rtmp connections
 skip_tunneling: used if you don't ever want to attempt rtmpt connections
 reconnect_count_limit: specify the max amount of reconnect attempts are made. If set to 0 reconnect attempts will occur indefinitely. Default is 10.
 reconnect_max_time_wait: specify the max amount of time to pass between reconnect attempts. The reconnect logic employs an exponential back-off algorithm so it delays each successive attempt expnentially with a cap at the max set here plus a random seed. Default is 10.
 sequential_connect: a boolean to enable or disable the sequential connect approach. By default it is disabled. This will try a connection one at a time and wait for a failure prior to trying the next type in the sequence.
 shotgun_connect: a boolean to enable or disable the shotgun approach. By default it is enabled.
 portArray: an array containing port numbers or NetConnectionTypes in the order they should be tried. By default is it [443,80,1935]. Added in 1.8.0 is the ability to pass in NetConnectionTypes so as to specify an exact protocol/port/proxy connect order.
 port_test: a boolean specifying whether to only run a port test for all available protocols over the specified ports in the portArray. It will fire events for updates and when it completes.

 It has an event,PARAM_EVT, that fires to notify the user of an event in the class. It has a param value which is an object which should be case to a string to read.

 If you are experiencing issues with proxies you can try setting the proxyType="best" as this will attempt to use a different connect method if normal attempts fail.

 USAGE:
 It's a simple use case really.. just use it as you would the built in NetConnection class. Just specify rtmp as the protocol and let
 the class handle the rest whether to use rtmpt or rtmp. In the case of encrypted still only pass in rtmp and it will resolve to rtmpe or rtmpte.
 The only caveat is that for netstreams you'd need to pass in a reference to the connection and not the main class.

 It also supports rtmfp. Using this library will support auto-reconnect if needed as well as
 some other hooks this lib buys. It would also be possible to switch between protocols using the same netconnectionsmart connection class.

 For example:

 var client_obj:Object = new Object();
 client_obj.serverMethod = function(e:Object):void
 {
 trace("server can call this");
 }

 var ncs:NetConnectionSmart = new NetConnectionSmart();
 ncs.client = client_obj;
 ncs.encrypted = true; //if this isn't specified it will default to rtmp/rtmpt.. if true it will try rtmpe/rtmpte

 ncs.addEventListener(NetStatusEvent.NET_STATUS,function(e:NetStatusEvent):void
 {
 trace("connection status: "+e.info.code);
 trace(ncs.uri);
 trace(ncs.protocol);

 switch (e.info.code)
 {
 case NetConnectionSmart.NETCONNECTION_CONNECT_SUCCESS:
 var ns:NetStream = new NetStream(ncs.connection);
 //do other netstream actions
 break;
 }
 });

 ncs.connect("rtmp://myserver.com/application");

 //Port array examples
 ncs.portArray = [443,80,1935];

 Alternate usage
 ncs.portArray = [
 new NetConnectionType(NetConnectionSmart.RTMP, "1935", "", NetConnectionSmart.PROXYTYPE_NONE),
 new NetConnectionType(NetConnectionSmart.RTMP, "443", "s", NetConnectionSmart.PROXYTYPE_BEST),
 new NetConnectionType(NetConnectionSmart.RTMP, "443"),
 new NetConnectionType(NetConnectionSmart.RTMP, "80", "", NetConnectionSmart.PROXYTYPE_HTTP),
 new NetConnectionType(NetConnectionSmart.RTMP, "80", "e", NetConnectionSmart.PROXYTYPE_CONNECT),
 new NetConnectionType(NetConnectionSmart.RTMP, "80", "", NetConnectionSmart.PROXYTYPE_CONNECTONLY),
 443,
 80,
 1935
 ];

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
    import flash.net.ObjectEncoding;
    import flash.net.Responder;
    import flash.utils.ByteArray;
    import flash.utils.Timer;

    public class NetConnectionSmart extends EventDispatcher
    {
        public static const PARAM_EVT:String = "NetConnectionSmartMsgEvent";
        public static const NETCONNECTION_CONNECT_CLOSED:String = "NetConnection.Connect.Closed";
        public static const NETCONNECTION_CONNECT_FAILED:String = "NetConnection.Connect.Failed";
        //noinspection JSUnusedGlobalSymbols
        public static const NETCONNECTION_CONNECT_NETWORKCHANGE:String = "NetConnection.Connect.NetworkChange";
        public static const NETCONNECTION_CONNECT_REJECTED:String = "NetConnection.Connect.Rejected";
        public static const NETCONNECTION_CONNECT_SUCCESS:String = "NetConnection.Connect.Success";
        public static const NETCONNECTION_PORT_TEST_COMPLETE:String = "NetConnection.PortTest.Complete";
        public static const NETCONNECTION_PORT_TEST_UPDATE:String = "NetConnection.PortTest.Update";
        public static const NETCONNECTION_RECONNECT_FAILED:String = "NetConnection.Reconnect.Failed";
        public static const NETCONNECTION_RECONNECT_INIT:String = "NetConnection.Reconnect.Init";
        public static const PROXYTYPE_BEST:String = "best";
        public static const PROXYTYPE_CONNECT:String = "CONNECT";
        public static const PROXYTYPE_CONNECTONLY:String = "CONNECTOnly";
        public static const PROXYTYPE_HTTP:String = "HTTP";
        public static const PROXYTYPE_NONE:String = "none";
        public static const RTMFP:String = "rtmfp";
        public static const RTMP:String = "rtmp";
        public static const RTMPT:String = "rtmpt";
        public static const VERSION:String = "NetConnectionSmart v 1.9.0";

        /**
         * Boolean to determine if a unique alphanumeric string should be passed at the end of the param set to the media server
         * @default false
         */
        public var append_guid:Boolean;
        /**
         * Boolean to define whether the class with attempt to automatically reconnect to a server when the connection is closed by a means outside of the close call
         * @default false
         */
        public var auto_reconnect:Boolean;
        public var default_port_only:Boolean;
        public var debug:Boolean;
        public var enable_rtmfp:Boolean;
        public var encrypted:Boolean;
        public var force_tunneling:Boolean;
        public var port_test:Boolean;
        public var recreate_guid:Boolean;
        public var secure:Boolean;
        public var sequential_connect:Boolean;
        public var shotgun_connect:Boolean = true;
        public var skip_tunneling:Boolean;

        public var connection_timeout:uint = 30;
        public var connection_rate:uint = 200;
        public var reconnect_count_limit:uint = 10;
        public var reconnect_max_time_wait:uint = 10;

        protected var _connect_string_init:String;
        protected var _ncTypes:Vector.<NetConnectionType>;

        private var _connectParams:Array;
        private var _connectParamsInit:Array;
        private var _portArray:Array = [443, 80, 1935];
        private var _initial_connect_run:Boolean;
        private var _is_connecting:Boolean;
        private var _was_connected:Boolean;
        private var _connect_init_time:Number;
        private var _response_time:Number;
        private var _ncClient:Object;
        private var _nc:PortConnection;
        private var _app_string:String;
        private var _guid:String;
        private var _proxy_type:String = "none";
        private var _server_string:String;
        private var _connectTimer:Timer;
        private var _reconnectTimer:Timer;
        private var _connection_attempt_count:uint;
        private var _object_encoding:uint = ObjectEncoding.AMF3;
        private var _reconnect_count:uint;

        /**
         * A replacement class for the build-in NetConnection class.
         */
        public function NetConnectionSmart()
        {
            _ncClient = {};
            _guid = GUID.create();
        }

        /**
         * @inheritDoc
         */
        public function set client(obj:Object):void
        {
            _ncClient = obj;
        }

        /**
         * @return A boolean whether the active netconnection is connected
         */
        public function get connected():Boolean
        {
            try
            {
                return _nc.connected;
            }
            catch (e:Error)
            {
            }

            return false;
        }

        /**
         * @return A boolean whether the active netconnection is connecting
         */
        public function get connecting():Boolean
        {
            return _is_connecting;
        }

        /**
         * @return Resolved active netconnection
         */
        public function get connection():PortConnection
        {
            return _nc;
        }

        //noinspection JSUnusedGlobalSymbols
        /**
         * @return A raw object with information about the current active netconnection
         */
        public function get connectionInfo():Object
        {
            return parseObj(connection);
        }

        //noinspection JSUnusedGlobalSymbols
        public function get connectParams():Array
        {
            return _connectParamsInit;
        }

        //noinspection JSUnusedGlobalSymbols
        public function set connectParams(paramArray:Array):void
        {
            _connectParamsInit = paramArray;
        }

        public function get guid():String
        {
            return _guid;
        }

        //noinspection JSUnusedGlobalSymbols
        /**
         * @see flash.net.NetConnection.objectEncoding
         */
        public function get objectEncoding():uint
        {
            return _nc ? _nc.objectEncoding : _object_encoding;
        }

        //noinspection JSUnusedGlobalSymbols
        public function set objectEncoding(encoding:uint):void
        {
            _object_encoding = encoding;
            if (_nc)
                _nc.objectEncoding = encoding;
        }

        public function get port():String
        {
            return _ncTypes[_nc.id].port;
        }

        public function get protocol():String
        {
            return _ncTypes[_nc.id].protocol;
        }

        /**
         * @see flash.net.NetConnection.proxyType
         */
        public function get proxyType():String
        {
            return _nc ? _nc.proxyType : _proxy_type;
        }

        //noinspection JSUnusedGlobalSymbols
        /**
         * @see flash.net.NetConnection.connectedProxyType
         */
        public function set proxyType(proxy_type:String):void
        {
            _proxy_type = proxy_type;
        }

        //noinspection JSUnusedGlobalSymbols
        public function get response_time():Number
        {
            return _response_time || -1;
        }

        /**
         * @see flash.net.NetConnection.connectedProxyType
         */
        public function get connectedProxyType():String
        {
            return _nc.connectedProxyType;
        }

        //noinspection JSUnusedGlobalSymbols
        /**
         * @see flash.net.NetConnection.uri
         */
        public function get uri():String
        {
            return _nc.uri;
        }

        //noinspection JSUnusedGlobalSymbols
        /**
         * @see flash.net.NetConnection.usingTLS
         */
        public function get usingTLS():Boolean
        {
            return _nc.usingTLS;
        }

        /**
         * array of uints which specify which ports to use during the connection sequence
         */
        public function get portArray():Array
        {
            return _portArray;
        }

        /**
         * Used to update/instantiate which ports will be used during the connection sequence.
         * @param portArray
         */
        public function set portArray(portArray:Array):void
        {
            _portArray = portArray;
            initConnectionTypes();
        }

        /**
         * @return Vector of NetConnectionTypes
         * @see com.gearsandcogs.utils.NetConnectionType
         */
        public function get netConnections():Vector.<NetConnectionType>
        {
            return _ncTypes;
        }

        /**
         *
         * @return Raw Object with parsed netconnection information for each NetConnectionType
         */
        public function get netConnectionsInfo():Vector.<Object>
        {
            return parseObj(netConnections) as Vector.<Object>;
        }

        public function get was_connected():Boolean
        {
            return _was_connected;
        }

        private static function parseObj(obj:*):Object
        {
            var myBA:ByteArray = new ByteArray();
            myBA.writeObject(obj);
            myBA.position = 0;
            return( myBA.readObject() );
        }

        /**
         * @see flash.net.NetConnection.call
         */
        public function call(command:String, responder:Responder = null, ...parameters):void
        {
            if (!_nc || !_nc.connected)
                throw(new Error("NetConnection must be connected in order to make a call on it."));

            _nc.call.apply(null, [command, responder].concat(parameters));
        }

        /**
         * Used to close the current active netconnection.
         * Supports a close command which simulates a server disconnect. This can
         * be useful when trying to debug/test a server reconnect logic block
         * @param is_dirty
         * @see flash.net.NetConnection.close
         */
        public function close(is_dirty:Boolean = false):void
        {
            if (_reconnectTimer)
            {
                _reconnectTimer.stop();
                _reconnectTimer = null;
            }

            if (!_nc)
                return;

            if (!is_dirty)
            {
                _was_connected = false;
                _nc.was_connected = false;
            }

            _nc.close();

            if (is_dirty)
                return;

            _nc = null;
            closeExtraNc();
        }

        /**
         * Kicks off the connection sequence for all ports
         * specified in the port array as well as for allowed protocols.
         * @see flash.net.NetConnection.connect
         */
        public function connect(command:String, ...parameters):void
        {
            if (debug)
                log(VERSION);

            //check for null connection param
            if (command == null)
            {
                _nc = new PortConnection(0, "", debug);
                _nc.connect(null);
                return;
            }

            if (connecting || connected)
                return;

            _connect_init_time = new Date().time;
            _is_connecting = true;

            //strip rtmp variants
            _connect_string_init = ~command.indexOf("://") ? command.substring(command.indexOf("://") + 3) : command;

            //strip port declaration
            if (~_connect_string_init.indexOf(":"))
            {
                var split_connect:Array = _connect_string_init.split(":");
                _connect_string_init = split_connect[0] + split_connect[1].substring(split_connect[1].indexOf("/"));
            }

            //setting very low connection rate but helps to avoid race conditions serverside
            if (shotgun_connect)
                connection_rate = 100;

            //create new guid
            if (recreate_guid && _initial_connect_run)
                _guid = GUID.create();

            initConnectionTypes();

            _connectParamsInit = parameters;
            _connectParams = append_guid ? parameters.concat(guid) : parameters;
            _server_string = _connect_string_init.substring(0, _connect_string_init.indexOf("/"));
            _app_string = _connect_string_init.substring(_connect_string_init.indexOf("/"));
            _initial_connect_run = true;

            _nc = null;
            closeExtraNc();

            if (_server_string == "" || _app_string.length < 2)
                throw(new Error("Invalid application path. Need server and application name"));

            if (secure && force_tunneling)
                throw(new Error("Secure connections cannot run over rtmpt. Either turn off force tunneling or the secure flag."));

            if (sequential_connect)
                initConnection();
            else
                initializeTimers();
        }

        protected function initConnectionTypes():void
        {
            if (skip_tunneling && force_tunneling)
                throw(new Error("Cannot force tunneling and skip tunneling. Please choose one or the other."));

            var assignmentOverrideArray:Array = [];
            var rtmfpArray:Array = [];
            var rtmpArray:Array = [];
            var rtmpConnectArray:Array = [];
            var rtmptArray:Array = [];

            for each(var r:Object in _portArray)
            {
                if (r is NetConnectionType)
                {
                    assignmentOverrideArray.push(r);
                    continue;
                }

                var port:String = r.toString();
                if (!force_tunneling)
                {
                    if (proxyType == PROXYTYPE_NONE)
                        rtmpConnectArray.push(new NetConnectionType(RTMP, port, encrypted ? "e" : secure ? "s" : "", PROXYTYPE_CONNECTONLY));
                    rtmpArray.push(new NetConnectionType(RTMP, port, encrypted ? "e" : secure ? "s" : "", proxyType));
                }
                if (enable_rtmfp)
                    rtmfpArray.push(new NetConnectionType(RTMFP, port));
                if (!skip_tunneling && !secure)
                    rtmptArray.push(new NetConnectionType(RTMPT, port, encrypted ? "e" : "", proxyType == PROXYTYPE_NONE ? PROXYTYPE_BEST : proxyType));
            }
            _ncTypes = Vector.<NetConnectionType>([].concat(assignmentOverrideArray, rtmfpArray, rtmpArray, rtmpConnectArray, rtmptArray));
        }

        protected function initPortConnection(nc_num:uint):NetConnectionType
        {
            var encrypted_secure_identifier:String = encrypted ? "Encrypted " : secure ? "Secure " : "";

            var curr_nct:NetConnectionType = _ncTypes[nc_num];
            var port_label:String = encrypted_secure_identifier + curr_nct.full_protocol + " " + curr_nct.port;
            var curr_pc:PortConnection = new PortConnection(nc_num, port_label, debug);

            curr_pc.connection_timeout = connection_timeout;
            curr_pc.objectEncoding = _object_encoding;
            curr_pc.proxyType = curr_nct.proxyType;

            curr_pc.client = _ncClient;
            curr_pc.addEventListener(PortConnection.STATUS_UPDATE, checkNetStatus);
            curr_nct.connection = curr_pc;

            return curr_nct;
        }

        private function acceptNc(portConnection:PortConnection):void
        {
            _nc = portConnection;

            _nc.removeEventListener(PortConnection.STATUS_UPDATE, checkNetStatus);
            _nc.deactivateHandlers();

            _nc.addEventListener(AsyncErrorEvent.ASYNC_ERROR, handleAsyncError);
            _nc.addEventListener(IOErrorEvent.IO_ERROR, handleIoError);
            _nc.addEventListener(NetStatusEvent.NET_STATUS, handleNetStatus);
            _nc.addEventListener(SecurityErrorEvent.SECURITY_ERROR, handleSecurityError);

            _nc.client = _ncClient;

            if (_connectTimer)
                _connectTimer.stop();

            closeExtraNc();
        }

        private function closeDownNc(pc:PortConnection):void
        {
            if (debug)
                log("Closing down NetConnection: " + pc.label);

            pc.removeEventListener(PortConnection.STATUS_UPDATE, checkNetStatus);
            pc.close();

            //cleanup listener
            pc.deactivateHandlers();
        }

        private function closeExtraNc():void
        {
            for each(var n:NetConnectionType in _ncTypes)
            {
                var portConnection:PortConnection = n.connection;
                if (portConnection && portConnection != _nc)
                {
                    closeDownNc(portConnection);
                    n.connection = null;
                }
            }
        }

        private function connectionSuccess(conn:PortConnection):void
        {
            _is_connecting = false;
            _was_connected = true;
            _reconnect_count = 0;
            _connection_attempt_count = 0;
            _response_time = new Date().time - _connect_init_time;
            acceptNc(conn);
            handleNetStatus(conn.status);
        }

        private function initConnection(connect_count:uint = 0):void
        {
            //all connection attempts have been tried
            if (connect_count >= _ncTypes.length)
            {
                if (_connectTimer)
                    _connectTimer.stop();
                return;
            }

            _connection_attempt_count = connect_count;
            var curr_nct:NetConnectionType = initPortConnection(connect_count);

            if (!curr_nct.connection.status)
                processConnection(curr_nct.connection, curr_nct.full_protocol, curr_nct.port, _connectParams);
        }

        private function initializeTimers():void
        {
            if (debug)
                log("Connecting at a rate of: " + connection_rate);

            if (_connectTimer)
                _connectTimer.stop();

            _connectTimer = new Timer(connection_rate);
            _connectTimer.addEventListener(TimerEvent.TIMER, function (e:TimerEvent):void
            {
                initConnection(_connectTimer.currentCount - 1);
            });

            _connectTimer.start();
        }

        private function log(msg:String):void
        {
            if (debug)
                trace("NetConnectionSmart: " + msg);
            dispatchEvent(new ParamEvent(PARAM_EVT, false, false, msg));
        }

        private function processConnection(connection:PortConnection, protocol:String, port:String, parameters:Array):void
        {
            if (default_port_only && port != "default")
                return;

            var portpass:String = port != "default" ? ":" + port : "";

            if (debug)
                log("connecting to: " + protocol + "://" + _server_string + portpass + _app_string + " with proxyType: " + connection.proxyType);

            connection.connect.apply(null, [protocol + "://" +
                _server_string + portpass + _app_string].concat(parameters));
        }

        protected function handleNetStatus(e:NetStatusEvent):void
        {
            if (debug && e.info && e.info.code)
                log(e.info.code);

            dispatchEvent(e);

            if (!auto_reconnect || !was_connected || (e.info.code != NETCONNECTION_CONNECT_CLOSED && e.info.code != NETCONNECTION_CONNECT_FAILED))
                return;

            if (reconnect_count_limit == 0 || (_reconnect_count < reconnect_count_limit))
            {
                if (debug)
                    log("attempting to reconnect");

                e.info.code = NETCONNECTION_RECONNECT_INIT;
                e.info.level = "status";
                _reconnect_count++;

                var calculated_reconnect_wait:uint = (Math.min(reconnect_max_time_wait, (Math.pow(2, _reconnect_count) - 1) / 2) + Math.random()) * 1000;
                _reconnectTimer = new Timer(calculated_reconnect_wait, 1);
                _reconnectTimer.addEventListener(TimerEvent.TIMER_COMPLETE, function (e:TimerEvent):void
                {
                    connect.apply(null, [_connect_string_init].concat(_connectParamsInit));
                    _reconnectTimer = null;
                });

                _reconnectTimer.start();
            }
            else
            {
                if (debug)
                    log("reconnect limit reached");

                e.info.code = NETCONNECTION_RECONNECT_FAILED;
                _reconnect_count = 0;
                close();
            }
            dispatchEvent(e);
        }

        private function checkNetStatus(e:Event):void
        {
            var targetConnection:PortConnection = e.target as PortConnection;

            if (debug)
                log(targetConnection.label + ": " + targetConnection.status.info.code);

            var status_count:uint = 0;
            var rejected_connection:PortConnection;

            for each(var i:NetConnectionType in _ncTypes)
            {
                var curr_connection:PortConnection = i.connection;

                if (!curr_connection)
                    continue;

                if (curr_connection.status)
                    status_count++;

                if (port_test)
                {
                    if (curr_connection.connected)
                        closeDownNc(curr_connection);
                }
                else if (!connected && curr_connection.connected)
                {
                    connectionSuccess(curr_connection);
                    return;
                }
                else if (!rejected_connection && curr_connection.rejected)
                    rejected_connection = curr_connection;
            }

            if (port_test)
                dispatchEvent(new NetStatusEvent(NetStatusEvent.NET_STATUS, false, false, {code: NETCONNECTION_PORT_TEST_UPDATE, internalTarget: targetConnection}));

            //if no success at all return the first rejected message or
            //return the status of the first connection in the array
            if (status_count == _ncTypes.length)
            {
                _is_connecting = false;

                if (port_test)
                {
                    if (debug)
                        log("port test complete");

                    dispatchEvent(new NetStatusEvent(NetStatusEvent.NET_STATUS, false, false, {code: NETCONNECTION_PORT_TEST_COMPLETE}));
                }
                else if (!rejected_connection)
                    handleNetStatus(_ncTypes[_ncTypes.length - 1].connection.status);
                else
                    handleNetStatus(rejected_connection.status);
            }
            else if (sequential_connect)
                initConnection(++_connection_attempt_count);
        }

        private function handleAsyncError(e:AsyncErrorEvent):void
        {
            if (debug)
                log(e.error.toString());
            dispatchEvent(e);
        }

        private function handleIoError(e:IOErrorEvent):void
        {
            if (debug)
                log(e.text);
            dispatchEvent(e);
        }

        private function handleSecurityError(e:SecurityErrorEvent):void
        {
            if (debug)
                log(e.text);
            dispatchEvent(e);
        }
    }
}