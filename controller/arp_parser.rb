require 'bindata'

class ARP < BinData::Record
  endian  :big

  bit48   :src_mac
  bit48   :dst_mac
  uint16  :ether_type, :value => 0x0806

  uint16  :hardware_type, :initial_value => 0x0001
  uint16  :protocol_type, :initial_value => 0x0800
  uint8   :hardware_address_size, :value => lambda {src_hardware_address.length}
  uint8   :protocol_address_size, :value => lambda {src_protocol_address.length}
  uint16  :opcode

  string  :src_hardware_address, :read_length => :hardware_address_size
  string  :src_protocol_address, :read_length => :protocol_address_size
  string  :dst_hardware_address, :read_length => :hardware_address_size
  string  :dst_protocol_address, :read_length => :protocol_address_size

  skip    :length => lambda { [64 - dst_protocol_address.offset - dst_protocol_address.num_bytes, 0].max }
end
