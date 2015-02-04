/**
 * Created by jhilton on 2/4/15.
 */
package com.gearsandcogs.utils
{
    import flash.events.Event;
    import flash.events.NetStatusEvent;
    import flash.utils.setTimeout;

    import org.flexunit.asserts.assertFalse;
    import org.flexunit.asserts.assertTrue;
    import org.flexunit.async.Async;

    public class NetConnectionSmartRMTPTDisconnectTest extends NetConnectionSmart
    {
        private var valid_connect_server:String = "wowzaec2demo.streamlock.net/vod/";

        public function NetConnectionSmartRMTPTDisconnectTest() {
            super();
        }

        [Before(async)]
        public function setUp():void {
            force_tunneling = true;
            connect(valid_connect_server);
            Async.proceedOnEvent(this, this, NetStatusEvent.NET_STATUS, 60000);
        }

        [Test(async)]
        public function testDisconnectTiming():void {
            assertTrue(connected);

            var test_complete:String = "test_complete";

            addEventListener(NetStatusEvent.NET_STATUS, handleNetStatus);
            function handleNetStatus(e:NetStatusEvent):void {
                trace(e.info.code);
                switch(e.info.code) {
                    case NETCONNECTION_CONNECT_CLOSED:
                        dispatchEvent(new Event(test_complete));
                        break;
                }
            }

            // we can't close the connection based on a netconnection success event so we delay
            setTimeout(function ():void {
                close();
                assertFalse(connected);
            }, 100);

            Async.handleEvent(this, this, test_complete, null, 60000, this);
        }

    }
}
