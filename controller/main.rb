require 'rubygems'
require 'lldp_parser'
require 'arp_parser'
require 'arp_table'
require 'topology'
require 'socket'

class SDNMPIController < Controller
  periodic_timer_event :flood_lldp_packets, 1
  periodic_timer_event :tick_arp_table, 1
  periodic_timer_event :tick_topology, 1
  periodic_timer_event :request_port_stats, 0.2

  def start
    @arp_table = ArpTable.new 5
    @topology = Topology.new 5
    @reserved_routes = {}
    @route_mutex = Mutex.new

    @server = TCPServer.open(2345)

    Thread.abort_on_exception = true
    @server_thread = Thread.new do
      while true do
        socket = @server.accept

        while s = socket.gets
          message = s.split ' '

          case message[0]
          when 'mpi_init'
            @arp_table.update_rank message[2].ip_s_to_i, message[1].to_i
          when 'begin_mpi_send'
            begin_mpi_send message[1].to_i, message[2].to_i
          when 'end_mpi_send'
            end_mpi_send message[1].to_i, message[2].to_i
          else 
            puts "unrecoginized message: #{message}"
          end
          socket.write 'ok\n'
        end

        socket.close
      end
    end
  end

  def begin_mpi_send src_rank, dst_rank
    src = @arp_table.resolve_rank src_rank
    dst = @arp_table.resolve_rank dst_rank

    if src and dst
      route = nil
      @route_mutex.synchronize {
        route = @topology.route src.mac, dst.mac, true
      }
      if route.nil?
        puts "no route"
      end

      cookie = (0xbabe << 16 | (src_rank & 0xff) << 8) | (dst_rank & 0xff)

      for i in 0 .. route.size - 2
        send_flow_mod_add(
          route[i].dst_id,
          :match => Match.new(
            :in_port => route[i].dst_port,
            :dl_src => src.mac,
            :dl_dst => dst.mac
          ),
          :priority => 0xffff,
          :actions => ActionOutput.new(route[i + 1].src_port),
          :cookie => cookie
        )
        send_flow_mod_add(
          route[i].dst_id,
          :match => Match.new(
            :in_port => route[i + 1].src_port,
            :dl_src => dst.mac,
            :dl_dst => src.mac
          ),
          :priority => 0xffff,
          :actions => ActionOutput.new(route[i].dst_port),
          :cookie => cookie
        )
      end

      route.each do |link|
        link.tx_connections += 1
        @topology.nodes[link.dst_id].ports[link.dst_port].rx_connections += 1
      end
      @reserved_routes[cookie] = route

      # puts "Flow added #{src.ip.to_ip_s} <-> #{dst.ip.to_ip_s}"
    else
      puts "Rank is not registered: #{message[1].to_i} or #{message[2].to_i}"
    end
  end

  def end_mpi_send src_rank, dst_rank
    cookie = (0xbabe << 16 | (src_rank & 0xff) << 8) | (dst_rank & 0xff)

    @topology.nodes.each do |dpid, node|
      if node.switch?
        send_flow_mod_delete(
          dpid,
          :cookie => cookie,
          :strict => true
        )
      end
    end

    @reserved_routes[cookie].each do |link|
      link.tx_connections -= 1
      @topology.nodes[link.dst_id].ports[link.dst_port].rx_connections -= 1
    end
    @reserved_routes[cookie] = nil

    # puts "Flow removed #{src} <-> #{dst}"
  end

  def tick_arp_table
    @arp_table.tick
    # @arp_table.dump
  end

  def tick_topology
    @topology.tick
    # @topology.dump
  end

  def request_port_stats
    @topology.nodes.each do |id, node|
      node.ports.keys.each do |port|
        send_message node.id, PortStatsRequest.new(:port_no=>port)
      end
    end
  end

  def stats_reply datapath_id, message
    port_stats = message.stats.find {|stats| stats.is_a? PortStatsReply }
    @topology.update_link_stats datapath_id, port_stats.port_no, port_stats if port_stats
  end

  def switch_ready datapath_id
    send_message datapath_id, FeaturesRequest.new
  end

  def switch_disconnected datapath_id
    @topology.remove_node datapath_id
  end

  def features_reply datapath_id, message
    ports = message.ports.select {|each|
      each.up?
    }.collect {|each|
      each.number
    }
    ports -= [65534]

    @topology.update_node :switch, datapath_id, ports
  end

  def packet_in datapath_id, message
    if message.lldp?
      analyze_lldp_packet datapath_id, message
      return
    end

    if message.arp?
      if message.arp_request?
        send_arp_reply datapath_id, message
        return
      end
      return
    end

    # Ad hoc.
    # Drop IPv6 multicast packets
    return if message.macda.to_s.start_with? '33:33:' or message.macda.broadcast?

    install_new_route datapath_id, message
  end

  def install_new_route datapath_id, message
    return unless message.macsa and message.macda

    src_mac = message.macsa.to_i
    dst_mac = message.macda.to_i

    route = nil
    @route_mutex.synchronize {
      route = @topology.route src_mac, dst_mac, false
    }
    if route.nil?
      puts "No route from #{message.macsa} to #{message.macda}"
      return
    end

    puts "Flow add #{message.macsa} <-> #{message.macda}"
    for i in 0 .. route.size - 2
      # Add flow entry
      send_flow_mod_add(
        route[i].dst_id,
        :match => Match.new(
          :in_port => route[i].dst_port,
          :dl_src => message.macsa,
          :dl_dst => message.macda
        ),
        :actions => ActionOutput.new(route[i + 1].src_port),
        :priority => 0x7fff
      )
      send_flow_mod_add(
        route[i].dst_id,
        :match => Match.new(
          :in_port => route[i + 1].src_port,
          :dl_src => message.macda,
          :dl_dst => message.macsa
        ),
        :actions => ActionOutput.new(route[i].dst_port),
        :priority => 0x7fff
      )
    end

    send_packet_out(
      route.last.src_id,
      :data => message.data,
      :actions => SendOutPort.new(route.last.src_port)
    )
  end

  def flood_lldp_packets
    @topology.nodes.each_pair {|datapath_id, node|
      next unless node.switch?

      node.ports.keys.each {|port|
        packet = get_lldp_packet datapath_id, port

        send_packet_out(
          datapath_id,
          :data => packet,
          :actions => SendOutPort.new(port)
        )
      }
    }
  end

  private
  def get_lldp_packet datapath_id, port
    packet = LLDP.new
    packet.tlvs = [
      TLV.new(
        :tlv_type => 1,
        :tlv_value => ChassisID.new(
          :subtype => 7,
          :id => datapath_id.uint64_to_s
        )
      ),
      TLV.new(
        :tlv_type => 2,
        :tlv_value => PortID.new(
          :subtype => 7,
          :id => port.uint16_to_s
        )
      ),
      TLV.new(
        :tlv_type => 3,
        :tlv_value => TimeToLive.new
      ),
      TLV.new(:tlv_type => 0)
    ]

    return packet.to_binary_s
  end

  def analyze_lldp_packet datapath_id, message
    packet = LLDP.read message.data
    dst_id = datapath_id
    dst_port = message.in_port

    # if this packet is from a host
    if packet.chassis_id.subtype == 4
      src_mac = packet.chassis_id.id.binary_s_to_i
      src_ip = packet.management_address.address.binary_s_to_i

      @arp_table.update src_ip, src_mac
      # Bi-directional
      @topology.update_link :host, src_mac, 0, dst_id, dst_port
      @topology.update_link :switch, dst_id, dst_port, src_mac, 0
    else
      src_id = packet.chassis_id.id.binary_s_to_i
      src_port = packet.port_id.id.to_uint16

      @topology.update_link :switch, src_id, src_port, dst_id, dst_port
    end
  end

  def send_arp_reply datapath_id, message
    request = ARP.read message.data
    entry = @arp_table.resolve_ip request.dst_protocol_address.binary_s_to_i

    if entry
      reply = ARP.new(
        :src_mac  =>  message.macsa.to_i,
        :dst_mac  =>  message.macda.to_i,
        :opcode   =>  2,
        :src_hardware_address =>  entry.mac.uint48_to_s,
        :src_protocol_address =>  request.dst_protocol_address,
        :dst_hardware_address =>  request.src_hardware_address,
        :dst_protocol_address =>  request.src_protocol_address,
      )

      send_packet_out(
        datapath_id,
        :data => reply.to_binary_s,
        :actions => SendOutPort.new(message.in_port)
      )
    end
  end
end
