defmodule Colcoord.Settings do
  use Ecto.Schema
  import Ecto.Changeset

  @mode_map %{
    0 => "Base 3P",
    1 => "Base 4P",
    2 => "Base 5-6P",
    3 => "Seafarers 3P",
    4 => "Seafarers 4P",
    5 => "Seafarers 5-6P",
    6 => "Cities & Knights 4P",
    7 => "Cities & Knights 5-6P",
    8 => "Sf + C&K 4P",
    9 => "Sf + C&K 6P",
    10 => "First Island 2P",
    11 => "Base 2P"
  }

  @all_modes Jason.encode!(Enum.sort(Map.keys(@mode_map)))

  schema "settings" do
    field :selected_modes, :string, default: @all_modes
    field :friends, :string, default: "[]"
    field :auto_join, :boolean, default: false
    field :last_game_found, :string

    timestamps(type: :utc_datetime)
  end

  def mode_map, do: @mode_map

  def changeset(settings, attrs) do
    settings
    |> cast(attrs, [:selected_modes, :friends, :auto_join, :last_game_found])
    |> validate_required([:selected_modes, :friends, :auto_join])
  end

  def decode_modes(%__MODULE__{selected_modes: json}) do
    case Jason.decode(json || "[]") do
      {:ok, v} -> v
      _ -> []
    end
  end

  def encode_modes(mode_codes) when is_list(mode_codes) do
    Jason.encode!(mode_codes)
  end

  def decode_friends(%__MODULE__{friends: json}) do
    case Jason.decode(json || "[]") do
      {:ok, v} -> v
      _ -> []
    end
  end

  def encode_friends(usernames) when is_list(usernames) do
    Jason.encode!(usernames)
  end

  def get_or_create do
    case Colcoord.Repo.one(__MODULE__) do
      nil ->
        %__MODULE__{}
        |> changeset(%{selected_modes: @all_modes, friends: "[]", auto_join: false})
        |> Colcoord.Repo.insert!()

      %__MODULE__{selected_modes: modes} = settings when modes in [nil, "[]", ""] ->
        settings
        |> changeset(%{selected_modes: @all_modes})
        |> Colcoord.Repo.update!()

      settings ->
        settings
    end
  end
end
