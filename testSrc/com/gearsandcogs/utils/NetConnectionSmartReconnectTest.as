/**
 * Created by jhilton on 4/24/14.
 */
package com.gearsandcogs.utils
{
    import flash.events.NetStatusEvent;

    import org.flexunit.asserts.assertEquals;
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
        public function testDisconnectReconnectSuccess():void
        {
            assertTrue(connected);

            Async.handleEvent(this, this, NetStatusEvent.NET_STATUS, handleNetStatus, 1000, this);
            function handleNetStatus(e:NetStatusEvent, test:NetConnectionSmartReconnectTest):void
            {
                assertEquals(e.info.code, NETCONNECTION_CONNECT_CLOSED);
            }

            close(true);
            assertFalse(connected);

            Async.handleEvent(this, this, NetStatusEvent.NET_STATUS, handleNetStatusReconnect, 60000, this);
            function handleNetStatusReconnect(e:NetStatusEvent, test:NetConnectionSmartReconnectTest):void
            {
                assertEquals(e.info.code, NETCONNECTION_CONNECT_SUCCESS);
            }
        }

        [Test(async)]
        public function testDisconnectReconnectFail():void
        {
            var ref:NetConnectionSmartReconnectTest = this;

            assertTrue(connected);

            Async.handleEvent(ref, ref, NetStatusEvent.NET_STATUS, handleNetStatusClose, 1000, ref);

            _connect_string_init = invalid_connect_server;
            close(true);
            assertFalse(connected);

            Async.handleEvent(ref, ref, NetStatusEvent.NET_STATUS, handleNetStatusReconnect, 60000, ref);

            function handleNetStatusClose(e:NetStatusEvent, test:NetConnectionSmartReconnectTest):void
            {
                assertEquals(NETCONNECTION_CONNECT_CLOSED, e.info.code);
            }
            function handleNetStatusReconnect(e:NetStatusEvent, test:NetConnectionSmartReconnectTest):void
            {
                //expect a connection failed first
                assertEquals(NETCONNECTION_CONNECT_FAILED, e.info.code);

                //then make sure we get a connection reconnect failed second
                Async.handleEvent(ref, ref, NetStatusEvent.NET_STATUS, handleNetStatusReconnectFail, 60000, ref);
            }
            function handleNetStatusReconnectFail(e:NetStatusEvent, test:NetConnectionSmartReconnectTest):void
            {
                assertEquals(NETCONNECTION_RECONNECT_FAILED, e.info.code);
            }
        }
    }
}