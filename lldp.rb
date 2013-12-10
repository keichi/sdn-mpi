require 'rubygems'
require 'lldp_parser'
require 'arp_parser'
require 'arp_table'
require 'topology'

class TopologyFinder < Controller
  periodic_timer_event :flood_lldp_packets, 1
  periodic_timer_event :tick_arp_table, 1
  periodic_timer_event :tick_topology, 1

  oneshot_timer_event :try_dijkstra, 3

  def try_dijkstra
    src = @arp_table.resolve_ip "192.168.0.1".ip_to_binary_s
    dst = @arp_table.resolve_ip "192.168.0.4".ip_to_binary_s

    route = @topology.route(src, dst)

    p route.map{|node| node.id.to_mac_s} if route
  end

  def start
    @arp_table = ArpTable.new 5
    @topology = Topology.new 5
  end

  def tick_arp_table
    @arp_table.tick
    @arp_table.dump
  end

  def tick_topology
    @topology.tick
    @topology.dump
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

    datapath_id = datapath_id.uint64_to_s
    ports = ports.map {|p| p.uint16_to_s}

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

    if message.macsa and message.macda
      src_mac = message.macsa.to_a.pack('C*')
      dst_mac = message.macda.to_a.pack('C*')

      route = @topology.route src_mac, dst_mac
      p route.map{|node| node.id.to_mac_s} if route
    end
  end

  def flood_lldp_packets
    @topology.nodes.each_pair {|datapath_id, node|
      next unless node.switch?

      node.ports.keys.each {|port|
        packet = get_lldp_packet datapath_id, port

        send_packet_out(
          datapath_id.unpack_i,
          :data => packet,
          :actions => SendOutPort.new(port.to_uint16)
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
          :id => datapath_id
        )
      ),
      TLV.new(
        :tlv_type => 2,
        :tlv_value => PortID.new(
          :subtype => 7,
          :id => port
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
    dst_id = datapath_id.uint64_to_s
    dst_port = message.in_port.uint16_to_s

    # if this packet is from a host
    if packet.chassis_id.subtype == 4
      src_mac = packet.chassis_id.id
      src_ip = packet.management_address.address

      @arp_table.update src_ip, src_mac
      # Bi-directional
      @topology.update_link :host, src_mac, 0.uint16_to_s, dst_id, dst_port
      @topology.update_link :switch, dst_id, dst_port, src_mac, 0.uint16_to_s
    else
      src_id = packet.chassis_id.id
      src_port = packet.port_id.id

      @topology.update_link :switch, src_id, src_port, dst_id, dst_port
    end
  end

  def send_arp_reply datapath_id, message
    request = ARP.read message.data
    mac = @arp_table.resolve_ip request.dst_protocol_address
    if mac
      #puts "ARP Reply: #{request.dst_protocol_address.unpack('C*').join('.')} -> #{mac.unpack('C*').map{|c| c.to_s(16)}.join(':')}"

      reply = ARP.new(
        :src_mac  =>  mac.unpack_i,
        :dst_mac  =>  request.src_hardware_address.unpack_i,
        :opcode   =>  2,
        :src_hardware_address =>  mac,
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
