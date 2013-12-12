require 'monkey_patches'

class ArpEntry
  attr_reader :ip
  attr_reader :mac

  def initialize(ip, mac)
    @last_updated = Time.now
    @ip = ip
    @mac = mac
  end

  def update(ip, mac)
    @last_updated = Time.now
    @ip = ip
    @mac = mac
  end

  def timed_out?(ttl)
    Time.now - @last_updated > ttl
  end
end

class ArpTable
  def initialize(ttl)
    @table = []
    @ttl = ttl
  end

  def update(ip, mac)
    arp_entry = @table.find {|entry| entry.ip == ip}
    if arp_entry
      arp_entry.update ip, mac
    else
      @table.push ArpEntry.new(ip, mac)
    end
  end

  def tick
    @table.delete_if {|entry| entry.timed_out? @ttl}
  end

  def resolve_ip(ip)
    arp_entry = @table.find {|entry| entry.ip == ip}

    arp_entry.mac if arp_entry
  end

  def resolve_mac(mac)
    arp_entry = @table.find {|entry| entry.mac == mac}

    arp_entry.ip if arp_entry
  end

  def dump
    puts "[ArpTable::dump]"
    @table.each do |entry|
      ip_addr = entry.ip.to_ip_s
      mac_addr = entry.mac.to_mac_s
      puts "#{ip_addr} at #{mac_addr}"
    end
  end
end
