defmodule Core.Snitch.Data.Schema do
  @moduledoc """
    Interface for DB tables with rules.
  """

  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset

      alias Core.Snitch.Data.Schema

      use Schema.{Stock}
    end
  end
end