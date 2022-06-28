defmodule UnicornHat.Display.API do
  @moduledoc """
  A behaviour that defines the interface of the Unicorn Hat Mini display.
  """

  @type rgb_decimal() :: 0..255
  @type degree_rotation() :: 0 | 90 | 180 | 270

  @doc """
  Clears the display.
  """
  @callback clear() :: :ok

  @doc """
  Sets the brightness of the LEDS on the display.
  """
  @callback set_all(rgb_decimal(), rgb_decimal(), rgb_decimal()) :: :ok

  @doc """
  Sets the brightness of the LEDS on the display.
  """
  @callback set_brightness(rgb_decimal()) :: :ok

  @doc """
  Sets RGB value for a single pixel on the display.
  """
  @callback set_pixel(integer(), integer(), rgb_decimal(), rgb_decimal(), rgb_decimal()) :: :ok

  @doc """
  Sets the rotation of the the display.
  """
  @callback set_rotation(degree_rotation()) :: :ok

  @doc """
  Transfers the current display buffer to the device.
  """
  @callback show() :: :ok

  @doc """
  The shutdown command is used to turn off the display.
  """
  @callback shutdown() :: :ok

  @doc """
  Startup for the GenServer
  """
  @callback start_link(keyword()) :: GenServer.on_start()
end
