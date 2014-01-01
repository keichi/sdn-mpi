class Node
  attr_reader :id, :ports
  attr_accessor :from, :cost, :done

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
