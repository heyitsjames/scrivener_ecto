defimpl Scrivener.Paginator, for: Atom do
  @moduledoc false

  @spec paginate(atom, Scrivener.Config.t()) :: Scrivener.Page.t()
  def paginate(atom, config) do
    atom
    |> Ecto.Queryable.to_query()
    |> Scrivener.Paginator.paginate(config)
  end
end
