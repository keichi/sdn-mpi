class Integer
  def uint16_to_s
    [self].pack('S')
  end

  def uint64_to_s
    [self >> 32 & ((1 << 32) - 1), self & ((1 << 32) - 1)].pack('N*')
  end

  def uint48_to_s
    [self >> 32 & ((1 << 16) - 1), self & ((1 << 32) - 1)].pack('nN')
  end

  def to_dpid_s
    [self >> 32 & ((1 << 32) - 1), self & ((1 << 32) - 1)].pack('NN').unpack('C8').join(':')
  end

  def to_mac_s
    sprintf('%012x', self).unpack('a2' * 6).join(':')
  end

  def to_ip_s
    [self].pack('N').unpack('C4').join('.')
  end
end

class String
  def to_uint16
    self.unpack('S')[0]
  end

  def binary_s_to_i
    self.unpack('C*').reduce(0) {|val, c| (val << 8 | c)}
  end

  def ip_s_to_i
    self.split('.').map {|s| s.to_i}.pack('C*').binary_s_to_i
  end
end
