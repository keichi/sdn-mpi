#!/usr/bin/python

from mininet.topo import Topo
from mininet.net import Mininet
from mininet.link import TCLink
from mininet.node import RemoteController
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

        self.addLink(s1, h1, bw=1000)
        self.addLink(s1, h2, bw=1000)
        self.addLink(s2, h3, bw=1000)
        self.addLink(s2, h4, bw=1000)

        self.addLink(s1, s3, bw=1000)
        self.addLink(s1, s4, bw=1000)
        self.addLink(s2, s3, bw=1000)
        self.addLink(s2, s4, bw=1000)

def runMPI():
    # Create network
    topo = TestTopo()
    net = Mininet(topo=topo, controller=lambda name: RemoteController(name, ip='127.0.0.1'), link=TCLink)
    # net = Mininet(topo=topo, controller=OVSController, link=TCLink)
    net.start()

    for host in net.hosts:
        host.cmd('../../tiny-lldpd/tlldpd -d -i 1')

    sleep(5)

    # Launch sshd on each hosts and output host IPs to machinefile
    pids = []
    f = open('./machines', 'w')
    for h in net.hosts:
        h.cmd('/usr/sbin/sshd -D -o UseDNS=no -u0 &')
        pid = int(h.cmd('echo $!'))
        pids.append(pid)
        f.write('%s\n' % h.IP())
    f.close()

    # Launch MPI application
    print "Starting MPI application:"
    print "----------------------------------------"
    net.hosts[0].cmdPrint('mpirun --machinefile ./machines --mca coll_tuned_priority 100 --mca coll_tuned_allreduce_algorithm 3 --mca coll_tuned_use_dynamic_rules 1 --mca coll_base_verbose 1 ./mpitest');
    print "----------------------------------------"
    print "MPI application finished."

    for pid in pids:
        h.cmd('kill -9 %s' % pid)
    net.hosts[0].cmd('killall -9 tlldpd')

    net.stop()
    cleanup()

if __name__ == '__main__':
    setLogLevel('info')
    runMPI()
