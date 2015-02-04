/**
 * Created by jhilton on 9/4/14.
 */
package com.gearsandcogs.utils
{
    import flash.events.Event;
    import flash.events.NetStatusEvent;

    import org.flexunit.asserts.assertEquals;
    import org.flexunit.async.Async;

    public class NetConnectionSmartPortTest extends NetConnectionSmart
    {
        private var return_count:uint;

        [Before(async)]
        public function setUp():void {
            port_test = true;
        }

        [After]
        public function tearDown():void {
            assertEquals(_ncTypes.length, return_count);
        }

        [Test(async)]
        public function testPortTestReturnCount():void {
            addEventListener(NetStatusEvent.NET_STATUS, handleNetStatus);
            function handleNetStatus(e:NetStatusEvent):void {
                switch(e.info.code) {
                    case NETCONNECTION_PORT_TEST_COMPLETE:
                        dispatchEvent(new Event(NETCONNECTION_PORT_TEST_COMPLETE));
                        break;
                    case NETCONNECTION_PORT_TEST_UPDATE:
                        return_count++;
                        break;
                }
            }

            connect("wowzaec2demo.streamlock.net/vod/");
            Async.handleEvent(this, this, NETCONNECTION_PORT_TEST_COMPLETE, null, 60000, this);
        }
    }
}
