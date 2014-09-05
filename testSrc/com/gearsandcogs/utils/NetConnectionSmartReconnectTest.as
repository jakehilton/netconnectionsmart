/**
 * Created by jhilton on 4/24/14.
 */
package com.gearsandcogs.utils
{
    import flash.events.Event;
    import flash.events.NetStatusEvent;
    import flash.utils.setTimeout;

    import org.flexunit.asserts.assertFalse;
    import org.flexunit.asserts.assertTrue;
    import org.flexunit.async.Async;

    public class NetConnectionSmartReconnectTest extends NetConnectionSmart
    {
        private var valid_connect_server:String = "wowzaec2demo.streamlock.net/vod/";
        private var invalid_connect_server:String = "wowzaec2demo.streamlockbad.net/vod/";

        public function NetConnectionSmartReconnectTest()
        {
            super();
        }

        [Before(async)]
        public function setUp():void
        {
            auto_reconnect = true;
            reconnect_count_limit = 1;
            connect(valid_connect_server);
            Async.proceedOnEvent(this, this, NetStatusEvent.NET_STATUS, 60000);
        }

        [After]
        public function tearDown():void
        {
            auto_reconnect = false;
        }

        [Test(async)]
        public function testDisconnectReconnectFail():void
        {
            assertTrue(connected);

            var test_complete:String = "test_complete";
            var closed_fired:Boolean = false;
            var failed_fired:Boolean = false;

            addEventListener(NetStatusEvent.NET_STATUS, handleNetStatus);
            function handleNetStatus(e:NetStatusEvent):void
            {
                switch (e.info.code)
                {
                    case NETCONNECTION_CONNECT_CLOSED:
                        closed_fired = true;
                        break;
                    case NETCONNECTION_CONNECT_FAILED:
                        failed_fired = true;
                        break;
                    case NETCONNECTION_RECONNECT_FAILED:
                        assertTrue(closed_fired);
                        assertTrue(failed_fired);
                        dispatchEvent(new Event(test_complete));
                        break;
                }
            }

            // we can't close the connection based on a netconnection success event so we delay
            setTimeout(function ():void
            {
                _connect_string_init = invalid_connect_server;
                close(true);
                assertFalse(connected);
            }, 100);

            Async.handleEvent(this, this, test_complete, null, 60000, this);
        }

        [Test(async)]
        public function testDisconnectReconnectSuccess():void
        {
            assertTrue(connected);

            var reconnect_success:String = "reconnect_success";
            var closed_fired:Boolean = false;
            var reconnect_fired:Boolean = false;

            addEventListener(NetStatusEvent.NET_STATUS, handleNetStatus);
            function handleNetStatus(e:NetStatusEvent):void
            {
                switch (e.info.code)
                {
                    case NETCONNECTION_CONNECT_CLOSED:
                        closed_fired = true;
                        break;
                    case NETCONNECTION_CONNECT_SUCCESS:
                        assertTrue(closed_fired);
                        assertTrue(reconnect_fired);
                        dispatchEvent(new Event(reconnect_success));
                        break;
                    case NETCONNECTION_RECONNECT_INIT:
                        reconnect_fired = true;
                        break;
                }
            }

            // we can't close the connection based on a netconnection success event so we delay
            setTimeout(function ():void
            {
                close(true);
                assertFalse(connected);
            }, 100);

            Async.handleEvent(this, this, reconnect_success, null, 60000, this);
        }
    }
}