require 'monkey_patches'
require 'node'
require 'link'

class Topology
  attr_accessor :nodes

  def initialize ttl
    @nodes = {}
    @ttl = ttl
  end

  def remove_node(id)
    @nodes.delete id
  end

  def update_node(type, id, ports)
    if @nodes.key? id
      @nodes[id].update
    else
      @nodes[id] = Node.new type, id, ports
    end
  end

  def update_link(src_type, src_id, src_port, dst_id, dst_port)
    update_node src_type, src_id, {}
    if @nodes.key? src_id and @nodes[src_id].ports.key? src_port
      link = @nodes[src_id].ports[src_port]
    end

    if link
      link.update
    else
      @nodes[src_id].ports[src_port] = Link.new src_id, src_port, dst_id, dst_port
    end
  end

  def update_link_stats datapath_id, port, port_stats
    return if not @nodes.key? datapath_id or @nodes[datapath_id].ports[port].nil?
  
    link = @nodes[datapath_id].ports[port]
    link.update_stats port_stats
  end

  def tick
    @nodes.delete_if {|id, node| node.timed_out? @ttl}
    @nodes.each do |id, node|
      node.ports.delete_if do |port, link|
        link.timed_out? @ttl if link
      end
    end
  end

  def dump
    puts "[Topology::dump]"
    puts "[Topology::dump::nodes]"
    @nodes.each do |id, node|
      puts "#{node.host? ? 'Host' : 'Switch'} #{node.host? ? id.to_mac_s : id.to_dpid_s} #{node.ports.keys}"
    end
    
    puts "[Topology::dump::links]"
    @nodes.each do |id, node|
      node.ports.each do |port, l|
        next unless l and @nodes.key? l.src_id and @nodes.key? l.dst_id

        src_id = @nodes[l.src_id].host? ? l.src_id.to_mac_s : l.src_id.to_dpid_s
        dst_id = @nodes[l.dst_id].host? ? l.dst_id.to_mac_s : l.dst_id.to_dpid_s

        src_port = l.src_port
        dst_port = l.dst_port
        tx_speed = sprintf"%.2f", l.tx_speed
        rx_speed = sprintf"%.2f", l.rx_speed

        puts "#{src_id}(#{src_port}) -> #{dst_id}(#{dst_port}) (#{tx_speed}, #{rx_speed})"
      end
    end
  end

  def get_route_info(route)
    info = []

    route.each_with_index do |node, i|
      next unless node.switch?

      node_info = {}
      node_info[:id] = node.id
      node_info[:in_port] = node.ports.find {|p, l| l.dst_id == route[i - 1].id}[0]
      node_info[:out_port] = node.ports.find {|p, l| l.dst_id == route[i + 1].id}[0]
      info.push node_info
    end

    info
  end

  def route(src_id, dst_id)
    return unless @nodes.key? src_id and @nodes.key? dst_id

    dijkstra src_id

    return if @nodes[src_id].cost.nil? or @nodes[dst_id].cost.nil?

    base = @nodes[dst_id]
    route = [base]

    while base = @nodes[base.from]
      route.push base
    end

    route.reverse
  end

  def cost(nid, sid)
    dijkstra sid
    @nodes[nid].cost
  end

  def dijkstra(sid)
    # initialize nodes
    @nodes.each do |id, node|
      node.cost = nil
      node.done = false
      node.from = nil
    end
    @nodes[sid].cost = 0

    loop do
      done_node = nil

      @nodes.each do |id, node|
        next if node.done or node.cost.nil?
        done_node = node if done_node.nil? or node.cost < done_node.cost
      end

      break unless done_node

      done_node.done = true
      done_node.ports.each do |port, link|
        # if nothing is connected to this port
        next if link.nil? or not @nodes.key? link.dst_id

        to = @nodes[link.dst_id]
        cost = done_node.cost + (1 + link.tx_speed / 1024.0 + link.rx_speed / 1024.0)
        from = done_node.id

        if to.cost.nil? or cost < to.cost
          to.cost = cost 
          to.from = from
        end
      end
    end
  end
end
