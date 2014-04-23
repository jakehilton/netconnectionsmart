package com.gearsandcogs.utils
{
    import flash.events.AsyncErrorEvent;
    import flash.events.Event;
    import flash.events.NetStatusEvent;
    import flash.events.TimerEvent;
    import flash.net.NetConnection;
    import flash.utils.Timer;
    import flash.utils.setTimeout;

    public class PortConnection extends NetConnection
    {
        public static const STATUS_UPDATE:String = "status_update";

        public var debug:Boolean;
        public var id:int;
        public var status:NetStatusEvent;
        public var label:String;
        public var connection_timeout:uint = 30;

        private var _connectedProxyType:String = "none";
        private var timeoutTimer:Timer;

        private var connect_init_time:Number;
        private var status_return_time:Number;

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
            return _connectedProxyType;
        }

        public function get response_time():uint
        {
            return status_return_time - connect_init_time;
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

        override public function connect(command:String, ...parameters):void
        {
            //start a timer here so we can watch this so if it doesn't connect in time we can kill it
            if (!timeoutTimer)
            {
                timeoutTimer = new Timer(connection_timeout * 1000, 1);
                timeoutTimer.addEventListener(TimerEvent.TIMER_COMPLETE, function (e:TimerEvent):void
                {
                    if (debug)
                        trace("PortConnection: connection timeout");

                    handleNetStatus(new NetStatusEvent(NetStatusEvent.NET_STATUS, false, false, {code: "NetConnection.Connect.Failed"}));
                    removeHandlers();
                    close();
                });
            }
            timeoutTimer.start();
            connect_init_time = new Date().time;
            super.connect.apply(null, [command].concat(parameters));
        }

        public function addHandlers():void
        {
            addEventListener(AsyncErrorEvent.ASYNC_ERROR, handleAsyncError);
            addEventListener(NetStatusEvent.NET_STATUS, handleNetStatus);
        }

        public function getProtocol():String
        {
            return uri.substring(0, uri.indexOf("://"));
        }

        public function onBWDone():void
        {
            //don't do anything
        }

        public function removeHandlers():void
        {
            if (timeoutTimer)
                timeoutTimer.stop();

            timeoutTimer = null;

            removeEventListener(AsyncErrorEvent.ASYNC_ERROR, handleAsyncError);
            removeEventListener(NetStatusEvent.NET_STATUS, handleNetStatus);
        }

        private function handleNetStatus(e:NetStatusEvent):void
        {
            timeoutTimer.stop();
            status_return_time = new Date().time;

            if (connected)
                _connectedProxyType = super.connectedProxyType;

            //if rejected connection came in we want to preserve that message
            if (!status || (status && status.info.code != "NetConnection.Connect.Rejected"))
            {
                if (debug)
                    trace("PortConnection " + label + " " + e.info.code);
                status = e;

                //hack alert..
                //need to delay the status update slightly so we can run operations like close based off of this event
                setTimeout(function ():void
                {
                    dispatchEvent(new Event(STATUS_UPDATE));
                }, 0);
            }
        }

        private function handleAsyncError(e:AsyncErrorEvent):void
        {
            if (debug)
                trace("PortConnection: " + e.toString());
        }
    }
}