require 'monkey_patches'

class Link
  attr_reader :src_id
  attr_reader :dst_id
  attr_reader :src_port
  attr_reader :dst_port
  attr_reader :tx_speed
  attr_reader :rx_speed

  def initialize(src_id, src_port, dst_id, dst_port)
    @last_updated = Time.now
    @src_id = src_id
    @src_port = src_port
    @dst_id = dst_id
    @dst_port = dst_port
    @last_stats_updated = Time.now
    @tx_bytes = 0
    @rx_bytes = 0
    @tx_speed = 0.0
    @rx_speed = 0.0
  end

  def update
    @last_updated = Time.now
  end

  def update_stats stats
    time_span = Time.now - @last_stats_updated
    @tx_speed = (stats.tx_bytes - @tx_bytes) / time_span * 8 / (1000 * 1000)
    @rx_speed = (stats.rx_bytes - @rx_bytes) / time_span * 8 / (1000 * 1000)

    @last_stats_updated = Time.now
    @tx_bytes = stats.tx_bytes
    @rx_bytes = stats.rx_bytes
  end

  def timed_out?(ttl)
    Time.now - @last_updated > ttl
  end
end

class Node
  attr_reader :id
  attr_reader :ports
  attr_accessor :from
  attr_accessor :cost
  attr_accessor :done

  def initialize(type, id, ports)
    @last_updated = Time.now
    @type = type
    @id = id
    # key: Port number
    # value: Node id (nil if nothing is connected)
    @ports = {}
    ports.each {|port| @ports[port] = nil}
    @from = nil
    @cost = nil
    @done = false
  end

  def host?
    @type == :host
  end

  def switch?
    @type == :switch
  end

  def timed_out?(ttl)
    Time.now - @last_updated > ttl
  end

  def update(src_port=nil, dst_id=nil)
    @last_updated = Time.now

    if src_port and dst_id
      @ports[src_port] = dst_id
    end
  end
end

class Topology
  attr_accessor :nodes

  def initialize ttl
    @nodes = {}
    @links = []
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
    link = @links.find do |l|
      (l.src_id == src_id) && (l.dst_id == dst_id) && (l.src_port == src_port) && (l.dst_port == dst_port)
    end

    if link
      link.update
    else
      @links.push Link.new src_id, src_port, dst_id, dst_port
    end

    update_node src_type, src_id, {}
    @nodes[src_id].update src_port, dst_id
  end

  def update_link_stats datapath_id, port, port_stats
    return if not @nodes.key? datapath_id or @nodes[datapath_id].ports[port].nil?
  
    link = @links.find {|l| l.src_id == datapath_id and l.src_port == port }
    link.update_stats port_stats if link
  end

  def tick
    @links.delete_if {|link| link.timed_out? @ttl}
    @nodes.delete_if {|id, node| node.timed_out? @ttl}
  end

  def dump
    puts "[Topology::dump]"
    puts "[Topology::dump::nodes]"
    @nodes.each do |id, node|
      puts "#{node.host? ? id.to_mac_s : id.to_dpid_s}: #{node.ports.keys}"
    end
    
    puts "[Topology::dump::links]"
    @links.each do |l|
      next unless @nodes.key? l.src_id and @nodes.key? l.dst_id

      src_id = @nodes[l.src_id].host? ? l.src_id.to_mac_s : l.src_id.to_dpid_s
      dst_id = @nodes[l.dst_id].host? ? l.dst_id.to_mac_s : l.dst_id.to_dpid_s

      src_port = l.src_port
      dst_port = l.dst_port
      tx_speed = sprintf"%.2f", l.tx_speed
      rx_speed = sprintf"%.2f", l.rx_speed

      puts "#{src_id}(#{src_port}) -> #{dst_id}(#{dst_port}) (#{tx_speed}, #{rx_speed})"
    end
  end

  def get_route_info(route)
    info = []

    route.each_with_index do |node, i|
      next unless node.switch?

      node_info = {}
      node_info[:id] = node.id
      node_info[:in_port] = node.ports.key route[i - 1].id
      node_info[:out_port] = node.ports.key route[i + 1].id
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
      done_node.ports.values.each do |nid|
        # if nothing is connected to this port
        next if nid.nil? or not @nodes.key? nid

        to = @nodes[nid]
        cost = done_node.cost + 1
        from = done_node.id

        if to.cost.nil? or cost < to.cost
          to.cost = cost 
          to.from = from
        end
      end
    end
  end
end
