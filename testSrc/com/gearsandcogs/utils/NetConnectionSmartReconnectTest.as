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
        public function NetConnectionSmartReconnectTest()
        {
            super();
        }

        [Before(async)]
        public function setUp():void
        {
            auto_reconnect = true;
            connect("wowzaec2demo.streamlock.net/vod/");
            Async.proceedOnEvent(this, this, NetStatusEvent.NET_STATUS, 60000);
        }

        [After]
        public function tearDown():void
        {
            auto_reconnect = false;
        }

        [Test(async)]
        public function testDisconnectReconnect():void
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
    }
}
