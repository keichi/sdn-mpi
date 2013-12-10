require 'bindata'

class EndOfLLDPDU < BinData::Record
end

class ChassisID < BinData::Record
  endian  :big

  uint8   :subtype
  string  :id, :read_length => lambda { tlv_length - 1 }
end

class PortID < BinData::Record
  endian  :big

  uint8   :subtype
  string  :id, :read_length => lambda { tlv_length - 1 }
end

class TimeToLive < BinData::Record
  endian  :big

  uint16  :ttl, :initial_value => 120
end

class PortDescription < BinData::Record
  endian  :big

  string  :description, :read_length => :tlv_length
end

class SystemName < BinData::Record
  endian  :big

  string  :name, :read_length => :tlv_length
end

class SystemDescription < BinData::Record
  endian  :big

  string  :description, :read_length => :tlv_length
end

class SystemCapabilities < BinData::Record
  endian  :big

  uint16  :system_capabilities
  uint16  :enabled_capabilities
end

class ManagementAddress < BinData::Record
  endian  :big
  hide    :address_length, :oid_length

  uint8   :address_length, :value => lambda { address.length }
  uint8   :address_subtype
  string  :address, :read_length => lambda { address_length - 1}
  uint8   :interface_numbering_subtype
  uint32  :interface_numbering
  uint8   :oid_length, :value => lambda { oid.length }
  string  :oid, :read_length => :oid_length
end

class Reserved < BinData::Record
  endian  :big

  skip    :length => :tlv_length
end

class Organizationally < BinData::Record
  endian :big

  uint24  :oui
  uint8   :subtype
  string  :information, :read_length => lambda { tlv_length - 4 }
end

class TLV < BinData::Record
  endian  :big
  hide    :tlv_length

  bit7    :tlv_type
  bit9    :tlv_length, :value => lambda { tlv_value.num_bytes }
  choice  :tlv_value, :selection => :tlv_type do
    end_of_lldpdu       0
    chassis_id          1
    port_id             2
    time_to_live        3
    port_description    4
    system_name         5
    system_description  6
    system_capabilities 7
    management_address  8
    organizationally    127
    reserved            :default
  end
end

class LLDP < BinData::Record
  endian  :big

  bit48     :src_mac
  bit48     :dst_mac, :initial_value => 0x0180c200000e
  uint16    :ether_type, :value => 0x88cc
  array     :tlvs, :type => :tlv, :read_until => lambda { element.tlv_type == 0 }
  skip      :length => lambda { [64 - tlvs.offset - tlvs.num_bytes, 0].max }

  def end_of_lldpdu
    get_tlv 0
  end

  def chassis_id
    get_tlv 1
  end

  def port_id
    get_tlv 2
  end

  def time_to_live
    get_tlv 3
  end

  def port_description
    get_tlv 4
  end

  def system_name
    get_tlv 5
  end

  def system_description
    get_tlv 6
  end

  def system_capabilities
    get_tlv 7
  end

  def management_address
    get_tlv 8
  end

  def get_tlv(type)
    tlv = self.tlvs.find {|t|
      t.tlv_type == type
    }

    return tlv.tlv_value if tlv
  end
end
