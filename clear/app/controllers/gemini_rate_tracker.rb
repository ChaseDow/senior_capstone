# In-memory rate tracking for Gemini free tier limits.
# Counters reset on server restart — that's fine for local dev.
class GeminiRateTracker
  RPM_LIMIT = 10
  RPD_LIMIT = 250

  @mutex = Mutex.new
  @timestamps = [] # array of Time objects for each request

  class << self
    def record!
      @mutex.synchronize { @timestamps << Time.current }
    end

    def usage
      @mutex.synchronize do
        now = Time.current
        prune!(now)

        minute_count = @timestamps.count { |t| t > now - 60 }
        day_count    = @timestamps.count { |t| t > now.beginning_of_day }

        {
          rpm:       minute_count,
          rpm_limit: RPM_LIMIT,
          rpd:       day_count,
          rpd_limit: RPD_LIMIT
        }
      end
    end

    def minute_available?
      usage[:rpm] < RPM_LIMIT
    end

    def day_available?
      usage[:rpd] < RPD_LIMIT
    end

    private

    # Drop timestamps older than today to prevent unbounded growth
    def prune!(now)
      cutoff = now.beginning_of_day
      @timestamps.reject! { |t| t < cutoff }
    end
  end
end
