defmodule UnicornHat.Display do
  @moduledoc File.read!("README.md")
             |> String.split(~r/<!-- DISPLAYDOC !-->/)
             |> Enum.drop(1)
             |> Enum.join("\n")

  require Logger
  use GenServer
  use Bitwise
  alias UnicornHat.HT16D35, as: Driver

  @cols 17
  @rows 7

  defmodule State do
    defstruct [:brightness, :buf, :disp, :left_matrix, :right_matrix, :rotation]
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Hat)
  end

  @impl GenServer
  def init(_opts) do
    disp = Enum.map(1..(@cols * @rows), fn _ -> [0, 0, 0] end)
    buf = Enum.map(1..(28 * 8 * 2), fn _ -> 0 end)

    state = %State{
      brightness: 0,
      buf: buf,
      disp: disp,
      left_matrix: nil,
      right_matrix: nil,
      rotation: 0
    }

    {:ok, state, {:continue, :init}}
  end

  @impl GenServer
  def handle_continue(:init, state) do
    {:ok, left_matrix_device} = Circuits.SPI.open("spidev0.0")
    {:ok, right_matrix_device} = Circuits.SPI.open("spidev0.1")
    left_matrix = {left_matrix_device, 8, 0}
    right_matrix = {right_matrix_device, 7, 28 * 8}
    Driver.initialize_device(left_matrix, state.buf)
    Driver.initialize_device(right_matrix, state.buf)
    :timer.send_interval(200, :tick)
    {:noreply, %{state | left_matrix: left_matrix, right_matrix: right_matrix}}
  end

  defp hsv_to_rgb(h, s, v) do
    if s == 0.0 do
      {v, v, v}
    else
      x = Float.floor(h * 6.0)
      f = h * 6.0 - x
      p = v * (1.0 - s)
      q = v * (1.0 - s * f)
      t = v * (1.0 - s * (1.0 - f))
      i = x |> round |> rem(6)

      case i do
        0 -> {v, t, p}
        1 -> {q, v, p}
        2 -> {p, v, t}
        3 -> {p, q, v}
        4 -> {t, p, v}
        5 -> {v, p, q}
      end
    end
  end

  defp get_shape(state) do
    if Enum.member?([90, 270], state.rotation) do
      {@rows, @cols}
    else
      {@cols, @rows}
    end
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, :ok, get_shape(state)}
  end

  @impl GenServer
  def handle_info({:set_pixel, {x, y, r, g, b}}, state) do
    offset =
      case state.rotation do
        0 ->
          x * @rows + y

        90 ->
          y = @cols - 1 - y
          y * @rows + x

        180 ->
          x = @cols - 1 - x
          y = @rows - 1 - y
          x * @rows + y

        270 ->
          x = @rows - 1 - x
          y * @rows + x
      end

    disp = List.replace_at(state.disp, offset, [r >>> 2, g >>> 2, b >>> 2])
    {:noreply, state |> struct(%{disp: disp})}
  end

  @impl GenServer
  def handle_info({:set_all, {r, g, b}}, state) do
    disp = Enum.map(1..(@cols * @rows), fn _ -> [r >>> 2, g >>> 2, b >>> 2] end)
    {:noreply, state |> struct(%{disp: disp})}
  end

  @impl GenServer
  def handle_info(:clear, state) do
    disp = Enum.map(1..(@cols * @rows), fn _ -> [0, 0, 0] end)
    {:noreply, state |> struct(%{disp: disp})}
  end

  @impl GenServer
  def handle_info({:set_brightness, brightness}, state) do
    Driver.set_brightness(brightness, state)
  end

  @impl GenServer
  def handle_info({:set_rotation, rotation}, state) do
    unless Enum.member?([0, 90, 180, 270], rotation) do
      raise "Rotation must be one of 0, 90, 180, 270"
    end

    {:noreply, state |> struct(%{rotation: rotation})}
  end

  @impl GenServer
  def handle_info(:shutdown, state) do
    Driver.shutdown(state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:tick, state) do
    Enum.map(Range.new(1, @rows), fn y ->
      Enum.map(Range.new(1, @cols), fn x ->
        hue = :os.system_time(:seconds) / 4.0 + x / (@cols * 2) + y / @rows
        {rx, gx, bx} = hsv_to_rgb(hue, 1.0, 1.0)

        {r, g, b} =
          {round(Float.floor(rx * 255)), round(Float.floor(gx * 255)),
           round(Float.floor(bx * 255))}

        Process.send(self(), {:set_pixel, {x, y, r, g, b}}, [])
      end)
    end)

    Driver.set_frame(state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(catch_all, state) do
    Logger.info(inspect(catch_all))
    {:noreply, state}
  end
end
