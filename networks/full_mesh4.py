#!/usr/bin/python

from mininet.topo import Topo
from mininet.net import Mininet
from mininet.link import TCLink
from mininet.node import RemoteController
from mininet.util import dumpNodeConnections
from mininet.log import setLogLevel
from mininet.cli import CLI
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

        self.addLink(s1, s2, bw=1000)
        self.addLink(s1, s3, bw=1000)
        self.addLink(s1, s4, bw=1000)

        self.addLink(s2, s3, bw=1000)
        self.addLink(s2, s4, bw=1000)

        self.addLink(s3, s4, bw=1000)

        self.addLink(s1, h1, bw=1000)
        self.addLink(s2, h2, bw=1000)
        self.addLink(s3, h3, bw=1000)
        self.addLink(s4, h4, bw=1000)

def perfTest():
    topo = TestTopo()
    net = Mininet(topo=topo, controller=lambda name: RemoteController(name, ip='127.0.0.1'), link=TCLink)
    net.start()
    print "Dumping connections"
    dumpNodeConnections(net.hosts)

    for host in net.hosts:
        host.cmdPrint('../../tiny-lldpd/tlldpd -d -i 1')

    sleep(5)

    net.pingAll()

    CLI(net)

    for host in net.hosts:
        host.cmdPrint('killall tlldpd')

    net.stop()
    cleanup()

if __name__ == '__main__':
    setLogLevel('info')
    perfTest()
