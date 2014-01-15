#!/usr/bin/python

from mininet.topo import Topo
from mininet.net import Mininet
from mininet.link import TCLink
from mininet.node import RemoteController
from mininet.util import dumpNodeConnections
from mininet.log import setLogLevel
from mininet.clean import cleanup
from time import sleep

class TestTopo(Topo):
    def __init__(self, **opts):
        Topo.__init__(self, **opts)
        s1 = self.addSwitch('s1')
        s2 = self.addSwitch('s2')
        s3 = self.addSwitch('s3')
        s4 = self.addSwitch('s4')

        h1 = self.addHost('h1')
        h2 = self.addHost('h2')
        h3 = self.addHost('h3')
        h4 = self.addHost('h4')

        self.addLink(s1, s3, bw=1000)
        self.addLink(s1, s4, bw=1000)
        self.addLink(s2, s3, bw=1000)
        self.addLink(s2, s4, bw=1000)

        self.addLink(s1, h1, bw=1000)
        self.addLink(s1, h2, bw=1000)
        self.addLink(s2, h3, bw=1000)
        self.addLink(s2, h4, bw=1000)

def perfTest():
    topo = TestTopo()
    net = Mininet(topo=topo, controller=lambda name: RemoteController(name, ip='127.0.0.1'), link=TCLink)
    net.start()
    print "Dumping connections"
    dumpNodeConnections(net.hosts)

    print "Launching LLDP daemons"
    for host in net.hosts:
        host.cmd('../../tiny-lldpd/tlldpd -d -i 1')

    sleep(3)

    net.pingAll()

    net.get('h3').cmd('iperf -sD')
    net.get('h4').cmd('iperf -sD')

    net.get('h1').cmd('iperf -c %s > /tmp/h1.txt &' % net.get('h3').IP())
    net.get('h2').cmd('sleep 1; iperf -c %s > /tmp/h2.txt &' % net.get('h4').IP())

    net.get('h1').cmd('wait $!')
    net.get('h2').cmd('wait $!')

    net.get('h1').cmdPrint("awk 'NR == 7 {print $7 $8}' /tmp/h1.txt")
    net.get('h2').cmdPrint("awk 'NR == 7 {print $7 $8}' /tmp/h2.txt")


    net.hosts[0].cmd('killall -9 tlldpd')
    net.hosts[0].cmd('killall -9 iperf')

    net.stop()
    cleanup()

if __name__ == '__main__':
    setLogLevel('info')
    perfTest()
