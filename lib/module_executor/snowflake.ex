defmodule DiscordGatewayGs.ModuleExecutor.Snowflake do
  @moduledoc """
  Functions that work on Snowflakes.
  """

  @typedoc """
  The type that represents snowflakes in JSON.

  In JSON, Snowflakes are typically represented as strings due
  to some languages not being able to represent such a large number.
  """
  @type external_snowflake :: String.t()

  @typedoc """
  The snowflake type.

  Snowflakes are 64-bit unsigned integers used to represent discord
  object ids.
  """
  @type t :: 0..0xFFFFFFFFFFFFFFFF

  @doc ~S"""
  Returns `true` if `term` is a snowflake; otherwise returns `false`.
  """
  defguard is_snowflake(term)
           when is_integer(term) and term in 0..0xFFFFFFFFFFFFFFFF

  @doc ~S"""
  Attempts to convert a term into a snowflake.
  """
  @spec cast(term) :: {:ok, t | nil} | :error
  def cast(value)
  def cast(nil), do: {:ok, nil}
  def cast(value) when is_snowflake(value), do: {:ok, value}

  def cast(value) when is_binary(value) do
    case Integer.parse(value) do
      {snowflake, _} -> cast(snowflake)
      _ -> :error
    end
  end

  def cast(_), do: :error

  @doc """
  Same as `cast/1`, except it raises an `ArgumentError` on failure.
  """
  @spec cast!(term) :: t | nil | no_return
  def cast!(value) do
    case cast(value) do
      {:ok, res} -> res
      :error -> raise ArgumentError, "Could not convert to a snowflake"
    end
  end

  @doc ~S"""
  Convert a snowflake into its external representation.
  """
  @spec dump(t) :: external_snowflake
  def dump(snowflake) when is_snowflake(snowflake), do: to_string(snowflake)

  # https://raw.githubusercontent.com/Kraigie/nostrum/master/lib/nostrum/snowflake.ex
end