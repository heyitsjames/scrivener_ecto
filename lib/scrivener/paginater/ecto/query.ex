defimpl Scrivener.Paginater, for: Ecto.Query do
  import Ecto.Query

  alias Scrivener.{Config, Page}

  @moduledoc false

  @spec paginate(Ecto.Query.t(), Scrivener.Config.t()) :: Scrivener.Page.t()
  def paginate(query, %Config{
        page_size: page_size,
        page_number: page_number,
        module: repo,
        caller: caller,
        options: options
      }) do

    group_joins? = Keyword.get(options, :group_joins, false)

    total_entries =
      Keyword.get_lazy(options, :total_entries, fn -> total_entries(query, repo, caller, group_joins?) end)

    total_pages = total_pages(total_entries, page_size)
    allow_overflow_page_number = Keyword.get(options, :allow_overflow_page_number, false)

    page_number =
      if allow_overflow_page_number, do: page_number, else: min(total_pages, page_number)

    %Page{
      page_size: page_size,
      page_number: page_number,
      entries: entries(query, repo, page_number, total_pages, page_size, caller, options),
      total_entries: total_entries,
      total_pages: total_pages
    }
  end

  defp entries(_, _, page_number, total_pages, _, _, _) when page_number > total_pages, do: []

  defp entries(query, repo, page_number, _, page_size, caller, options) do
    offset = Keyword.get_lazy(options, :offset, fn -> page_size * (page_number - 1) end)

    query
    |> offset(^offset)
    |> limit(^page_size)
    |> repo.all(caller: caller)
  end

  defp total_entries(query, repo, caller, group_joins?) do
    base_query =
      query
      |> exclude(:preload)
      |> exclude(:order_by)

    total_entries = 
      case group_joins? do
        true ->
          base_query
          |> group_by([x], [x.id])
          |> aggregate()
          |> repo.one(caller: caller)

        false ->
          base_query
          |> aggregate()
          |> repo.one(caller: caller)
      end

    total_entries || 0
  end

  defp aggregate(%{distinct: %{expr: [_ | _]}} = query) do
    query
    |> exclude(:select)
    |> count()
  end

  defp aggregate(
         %{
           group_bys: [
             %Ecto.Query.QueryExpr{
               expr: [
                 {{:., [], [{:&, [], [source_index]}, field]}, [], []} | _
               ]
             }
             | _
           ]
         } = query
       ) do
    query
    |> exclude(:select)
    |> select([{x, source_index}], struct(x, ^[field]))
    |> count()
  end

  defp aggregate(query) do
    query
    |> exclude(:select)
    |> select(count("*"))
  end

  defp count(query) do
    query
    |> subquery
    |> select(count("*"))
  end

  defp total_pages(0, _), do: 1

  defp total_pages(total_entries, page_size) do
    (total_entries / page_size) |> Float.ceil() |> round
  end
end
