module CalendarHelper
  def calendar_weeks(date)
    start_date = date.beginning_of_month.beginning_of_week(:sunday)
    end_date   = date.end_of_month.end_of_week(:sunday)

    (start_date..end_date).to_a.in_groups_of(7)
  end
end
