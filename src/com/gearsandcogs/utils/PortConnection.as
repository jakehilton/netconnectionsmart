package com.gearsandcogs.utils
{
    import flash.events.AsyncErrorEvent;
    import flash.events.Event;
    import flash.events.NetStatusEvent;
    import flash.events.TimerEvent;
    import flash.net.NetConnection;
    import flash.utils.Timer;

    public class PortConnection extends NetConnection
    {
        public static const STATUS_UPDATE:String = "status_update";

        public var debug:Boolean;
        public var id:int;
        public var status:NetStatusEvent;
        public var response_time:Number;
        public var label:String;
        public var connection_timeout:uint = 30;

        private var _internal_event_handlers_deactivated:Boolean;
        private var _was_connected:Boolean;
        private var _connected_proxy_type:String = "none";
        private var _connect_init_time:Number;
        private var _timeoutTimer:Timer;

        public function PortConnection(id:int, label:String, debug:Boolean = false) {
            super();
            this.debug = debug;
            this.id = id;
            this.label = label;
            addHandlers();
        }

        override public function get connectedProxyType():String {
            return _connected_proxy_type;
        }

        public function set connectedProxyType(s:String):void {
            _connected_proxy_type = s;
        }

        public function get rejected():Boolean {
            try {
                return status.info.code == NetConnectionSmart.NETCONNECTION_CONNECT_REJECTED;
            }
            catch(e:Error) {
                //no status info object exists
            }

            return false;
        }

        public function get was_connected():Boolean {
            return _was_connected;
        }

        public function set was_connected(b:Boolean):void {
            _was_connected = b;
        }

        private static function log(msg:String):void {
            trace("PortConnection: " + msg);
        }

        override public function connect(command:String, ...rest):void {
            //start a timer here so we can watch this so if it doesn't connect in time we can kill it
            if(!_timeoutTimer) {
                _timeoutTimer = new Timer(connection_timeout * 1000, 1);
                _timeoutTimer.addEventListener(TimerEvent.TIMER_COMPLETE, function (e:TimerEvent):void {
                    if(debug)
                        log("connection timeout");

                    handleNetStatus(new NetStatusEvent(NetStatusEvent.NET_STATUS, false, false,
                        {code: NetConnectionSmart.NETCONNECTION_CONNECT_FAILED}));
                    deactivateHandlers();
                });
            }
            _timeoutTimer.start();
            _connect_init_time = new Date().time;
            super.connect.apply(null, [command].concat(rest));
        }

        public function addHandlers():void {
            addEventListener(AsyncErrorEvent.ASYNC_ERROR, handleAsyncError);
            addEventListener(NetStatusEvent.NET_STATUS, handleNetStatus);
        }

        public function deactivateHandlers():void {
            if(_timeoutTimer)
                _timeoutTimer.stop();

            _timeoutTimer = null;
            _internal_event_handlers_deactivated = true;
        }

        //noinspection JSUnusedGlobalSymbols
        public function getProtocol():String {
            return uri.substring(0, uri.indexOf("://"));
        }

        //noinspection JSUnusedGlobalSymbols
        public function onBWDone():void {
            //don't do anything
        }

        private function handleNetStatus(e:NetStatusEvent):void {
            if(_internal_event_handlers_deactivated)
                return;

            _timeoutTimer.stop();
            response_time = new Date().time - _connect_init_time;

            if(connected) {
                was_connected = true;
                connectedProxyType = super.connectedProxyType;
            }

            //if rejected connection came in we want to preserve that message
            if(!status || (status && status.info.code != NetConnectionSmart.NETCONNECTION_CONNECT_REJECTED)) {
                if(debug)
                    log(label + " " + e.info.code);

                status = e;
                dispatchEvent(new Event(STATUS_UPDATE));
            }
        }

        private function handleAsyncError(e:AsyncErrorEvent):void {
            if(_internal_event_handlers_deactivated)
                return;

            if(debug)
                log(e.toString());
        }
    }
}