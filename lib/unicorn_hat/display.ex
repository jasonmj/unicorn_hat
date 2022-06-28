defmodule UnicornHat.Display do
  @moduledoc File.read!("README.md")
             |> String.split(~r/<!-- DISPLAYDOC !-->/)
             |> Enum.drop(1)
             |> Enum.join("\n")

  @behaviour UnicornHat.Display.API
  require Logger
  use GenServer
  use Bitwise
  alias UnicornHat.HT16D35, as: Driver

  @cols 17
  @rows 7

  defmodule State do
    defstruct [:brightness, :buf, :disp, :left_matrix, :right_matrix, :rotation]
  end

  @impl true
  def clear() do
    GenServer.cast(__MODULE__, :clear)
  end

  @impl true
  def set_all(r, g, b) do
    Logger.info("setting all")
    GenServer.cast(__MODULE__, {:set_all, {r, g, b}})
  end

  @impl true
  def set_brightness(brightness) do
    GenServer.cast(__MODULE__, {:set_brightness, brightness})
  end

  @impl true
  def set_pixel(x, y, r, g, b) do
    GenServer.cast(__MODULE__, {:set_pixel, {x, y, r, g, b}})
  end

  @impl true
  def set_rotation(rotation) do
    GenServer.cast(__MODULE__, {:set_rotation, rotation})
  end

  @impl true
  def show() do
    GenServer.cast(__MODULE__, :show)
  end

  @impl true
  def shutdown() do
    GenServer.cast(__MODULE__, :shutdown)
  end

  @impl true
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
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
    {:noreply, %{state | left_matrix: left_matrix, right_matrix: right_matrix}}
  end

  @impl GenServer
  def handle_cast(:clear, state) do
    disp = Enum.map(1..(@cols * @rows), fn _ -> [0, 0, 0] end)
    {:noreply, %{state | disp: disp}}
  end

  @impl GenServer
  def handle_cast({:set_all, {r, g, b}}, state) do
    Logger.info("handlle :set_all")
    disp = Enum.map(1..(@cols * @rows), fn _ -> [r >>> 2, g >>> 2, b >>> 2] end)
    Logger.debug("#{inspect(disp)}")
    {:noreply, %{state | disp: disp}}
  end

  @impl GenServer
  def handle_cast({:set_brightness, brightness}, state) do
    Driver.set_brightness(brightness, state.left_matrix, state.right_matrix)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:set_pixel, {x, y, r, g, b}}, state) do
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
    {:noreply, %{state | disp: disp}}
  end

  @impl GenServer
  def handle_cast({:set_rotation, rotation}, state) do
    unless Enum.member?([0, 90, 180, 270], rotation) do
      raise "Rotation must be one of 0, 90, 180, 270"
    end

    {:noreply, %{state | rotation: rotation}}
  end

  @impl GenServer
  def handle_cast(:show, state) do
    Driver.set_frame(state.buf, state.disp, state.left_matrix, state.right_matrix)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:shutdown, state) do
    Driver.shutdown(state.left_matrix, state.right_matrix)
    {:noreply, state}
  end
end
