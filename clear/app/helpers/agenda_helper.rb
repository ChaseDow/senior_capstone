module AgendaHelper
  def agenda_page_url(page)
    url_for(request.query_parameters.merge(page: page))
  end
end
