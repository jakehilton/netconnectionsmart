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
        public var label:String;
        public var connection_timeout:uint = 30;

        private var _internal_event_handlers_deactivated:Boolean;
        private var _was_connected:Boolean;
        private var _connected_proxy_type:String = "none";
        private var _connect_init_time:Number;
        private var _status_return_time:Number;
        private var _timeoutTimer:Timer;

        public function PortConnection(id:int, label:String, debug:Boolean = false)
        {
            super();
            this.debug = debug;
            this.id = id;
            this.label = label;
            addHandlers();
        }

        override public function get connectedProxyType():String
        {
            return _connected_proxy_type;
        }

        public function get response_time():uint
        {
            return _status_return_time - _connect_init_time;
        }

        public function get rejected():Boolean
        {
            try
            {
                return status.info.code == "NetConnection.Connect.Rejected";
            }
            catch (e:Error)
            {
            }

            return false;
        }

        public function get was_connected():Boolean
        {
            return _was_connected;
        }

        public function set was_connected(b:Boolean):void
        {
            _was_connected = b;
        }

        override public function connect(command:String, ...parameters):void
        {
            //start a timer here so we can watch this so if it doesn't connect in time we can kill it
            if (!_timeoutTimer)
            {
                _timeoutTimer = new Timer(connection_timeout * 1000, 1);
                _timeoutTimer.addEventListener(TimerEvent.TIMER_COMPLETE, function (e:TimerEvent):void
                {
                    if (debug)
                        log("connection timeout");

                    handleNetStatus(new NetStatusEvent(NetStatusEvent.NET_STATUS, false, false, {code: "NetConnection.Connect.Failed"}));
                    deactivateHandlers();
                });
            }
            _timeoutTimer.start();
            _connect_init_time = new Date().time;
            super.connect.apply(null, [command].concat(parameters));
        }

        public function addHandlers():void
        {
            addEventListener(AsyncErrorEvent.ASYNC_ERROR, handleAsyncError);
            addEventListener(NetStatusEvent.NET_STATUS, handleNetStatus);
        }

        public function deactivateHandlers():void
        {
            if (_timeoutTimer)
                _timeoutTimer.stop();

            _timeoutTimer = null;
            _internal_event_handlers_deactivated = true;
        }

        public function getProtocol():String
        {
            return uri.substring(0, uri.indexOf("://"));
        }

        public function onBWDone():void
        {
            //don't do anything
        }

        private function log(msg:String):void
        {
            trace("PortConnection: " + msg);
        }

        private function handleNetStatus(e:NetStatusEvent):void
        {
            if (_internal_event_handlers_deactivated)
                return;

            _timeoutTimer.stop();
            _status_return_time = new Date().time;

            if (connected)
            {
                _was_connected = true;
                _connected_proxy_type = super.connectedProxyType;
            }

            //if rejected connection came in we want to preserve that message
            if (!status || (status && status.info.code != "NetConnection.Connect.Rejected"))
            {
                if (debug)
                    log(label + " " + e.info.code);
                status = e;

                //hack alert..
                //need to delay the status update slightly so we can run operations like close based off of this event
                var statusDelayTimer:Timer = new Timer(0, 1);
                statusDelayTimer.addEventListener(TimerEvent.TIMER_COMPLETE, function (e:TimerEvent):void
                {
                    dispatchEvent(new Event(STATUS_UPDATE));
                });
                statusDelayTimer.start();
            }
        }

        private function handleAsyncError(e:AsyncErrorEvent):void
        {
            if (_internal_event_handlers_deactivated)
                return;

            if (debug)
                log(e.toString());
        }
    }
}