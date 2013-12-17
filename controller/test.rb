require 'rubygems'
require './topology'

topo = Topology.new 5
topo.update_node :switch, 1, {}
topo.update_node :switch, 2, {}
topo.update_node :switch, 3, {}
topo.update_node :switch, 4, {}
topo.update_node :host, 0xa, {}
topo.update_node :host, 0xb, {}
topo.update_node :host, 0xc, {}
topo.update_node :host, 0xd, {}

topo.update_link :host, 0xa, 0, 1, 1
topo.update_link :host, 0xb, 0, 1, 2
topo.update_link :host, 0xc, 0, 2, 1
topo.update_link :host, 0xd, 0, 2, 2

topo.update_link :switch, 1, 1, 0xa, 0
topo.update_link :switch, 1, 2, 0xb, 0
topo.update_link :switch, 2, 1, 0xc, 0
topo.update_link :switch, 2, 2, 0xd, 0

topo.update_link :switch, 1, 3, 3, 1
topo.update_link :switch, 1, 4, 4, 1
topo.update_link :switch, 2, 3, 3, 2
topo.update_link :switch, 2, 4, 4, 2

topo.update_link :switch, 3, 1, 1, 3
topo.update_link :switch, 4, 1, 1, 4
topo.update_link :switch, 3, 2, 2, 3
topo.update_link :switch, 4, 2, 2, 4

topo.dump

p topo.route(0xa, 0xb).map{|node| node.id}
p topo.route(0xb, 0xd).map{|node| node.id}
p topo.route(0xa, 0xc).map{|node| node.id}
