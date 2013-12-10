class Integer
  def uint16_to_s
    [self].pack('S')
  end

  def uint64_to_s
    [self >> 32 & 0xffffffff, self & 0xffffffff].pack('N*')
  end
end

class String
  def to_mac_s
    self.unpack('C*').map{|c| c.to_s(16)}.join(':')
  end

  def to_ip_s
    self.unpack('C*').join('.')
  end

  def ip_to_binary_s
    self.split('.').map{|x| x.to_i}.pack('C*')
  end

  def to_uint16
    self.unpack('S')[0]
  end

  def unpack_i
    self.unpack('C*').reduce(0) {|val, c| (val << 8 | c)}
  end
end
