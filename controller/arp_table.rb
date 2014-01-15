require 'monkey_patches'

class ArpEntry
  attr_reader :ip
  attr_reader :mac
  attr_accessor :rank

  def initialize(ip, mac)
    @last_updated = Time.now
    @ip = ip
    @mac = mac
    @rank = 0
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

  def update_rank(ip, rank)
    arp_entry = @table.find {|entry| entry.ip == ip}
    arp_entry.rank = rank if arp_entry
  end

  def tick
    @table.delete_if {|entry| entry.timed_out? @ttl}
  end

  def resolve_ip(ip)
    @table.find {|entry| entry.ip == ip}
  end

  def resolve_rank(rank)
    @table.find {|entry| entry.rank == rank}
  end

  def dump
    puts "[ArpTable::dump]"
    @table.each do |entry|
      ip_addr = entry.ip.to_ip_s
      mac_addr = entry.mac.to_mac_s
      puts "rank #{entry.rank} is #{ip_addr} at #{mac_addr}"
    end
  end
end
