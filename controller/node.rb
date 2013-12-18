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
    # value: Link object (nil if nothing is connected)
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

  def update
    @last_updated = Time.now
  end
end
