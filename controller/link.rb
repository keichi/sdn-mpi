class Link
  attr_reader :src_id, :dst_id, :src_port, :dst_port, :tx_speed, :rx_speed

  def initialize(src_id, src_port, dst_id, dst_port)
    @last_updated = Time.now
    @src_id = src_id
    @src_port = src_port
    @dst_id = dst_id
    @dst_port = dst_port
    @last_stats_updated = Time.now
    @tx_bytes = 0
    @rx_bytes = 0
    @tx_speed = 0.0
    @rx_speed = 0.0
  end

  def update
    @last_updated = Time.now
  end

  def update_stats stats
    time_span = Time.now - @last_stats_updated
    @tx_speed = (stats.tx_bytes - @tx_bytes) / time_span * 8 / (1024 * 1024)
    @rx_speed = (stats.rx_bytes - @rx_bytes) / time_span * 8 / (1024 * 1024)

    @last_stats_updated = Time.now
    @tx_bytes = stats.tx_bytes
    @rx_bytes = stats.rx_bytes
  end

  def timed_out?(ttl)
    Time.now - @last_updated > ttl
  end

  def cost
    1 + @tx_speed / 1024.0 + @rx_speed / 1024.0
  end
end
