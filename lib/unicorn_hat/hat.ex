defmodule UnicornHat.Hat do
  require Logger
  use GenServer
  use Bitwise
  alias Circuits.SPI
  alias UnicornHat.Hardware

  # Holtek HT16D35
  @cmd_soft_reset 0xCC
  @cmd_global_brightness 0x37
  @cmd_com_pin_ctrl 0x41
  @cmd_row_pin_ctrl 0x42
  @cmd_write_display 0x80
  @cmd_system_ctrl 0x35
  @cmd_scroll_ctrl 0x20

  @cols 17
  @rows 7

  # Buttons are unused here, but shown for reference
  # @button_a 5
  # @button_b 6
  # @button_x 16
  # @button_y 20

  defmodule State do
    defstruct [:brightness, :buf, :disp, :left_matrix, :right_matrix]
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Hat)
  end

  @impl GenServer
  def init(_opts) do
    {:ok, left_matrix_device} = Circuits.SPI.open("spidev0.0")
    {:ok, right_matrix_device} = Circuits.SPI.open("spidev0.1")
    disp = Enum.map(1..(@cols * @rows), fn _ -> [0, 0, 0] end)
    buf = Enum.map(1..(28 * 8 * 2), fn _ -> 0 end)

    state = %State{
      brightness: 0,
      buf: buf,
      disp: disp,
      left_matrix: {left_matrix_device, 8, 0},
      right_matrix: {right_matrix_device, 7, 28 * 8}
    }

    initialize_device(state.left_matrix, state.buf)
    initialize_device(state.right_matrix, state.buf)
    :timer.send_interval(200, :tick)
    {:ok, state}
  end

  defp initialize_device({device, pin, offset}, buf) do
    xfer(device, pin, <<@cmd_soft_reset>>)
    xfer(device, pin, <<@cmd_global_brightness, 0x01>>)
    xfer(device, pin, <<@cmd_scroll_ctrl, 0x00>>)
    xfer(device, pin, <<@cmd_system_ctrl, 0x00>>)

    xfer(
      device,
      pin,
      <<@cmd_write_display, 0x00>> <>
        :erlang.list_to_binary(Enum.slice(buf, Range.new(offset, offset + 28 * 8)))
    )

    xfer(device, pin, <<@cmd_com_pin_ctrl, 0xFF>>)
    xfer(device, pin, <<@cmd_row_pin_ctrl, 0xFF, 0xFF, 0xFF, 0xFF>>)
    xfer(device, pin, <<@cmd_system_ctrl, 0x03>>)
  end

  defp shutdown(state) do
    Enum.map([state.left_matrix, state.right_matrix], fn {device, pin, _offset} ->
      xfer(device, pin, <<@cmd_com_pin_ctrl, 0x00>>)
      xfer(device, pin, <<@cmd_row_pin_ctrl, 0x00, 0x00, 0x00, 0x00>>)
      xfer(device, pin, <<@cmd_system_ctrl, 0x00>>)
    end)
  end

  defp xfer(device, _pin, command) do
    SPI.transfer(device, command)
  end

  def show(state) do
    buf =
      Enum.reduce(Range.new(1, @cols * @rows - 1), state.buf, fn i, acc ->
        {lut_index, _} = List.pop_at(Hardware.get_lut(), i)
        [ir, ig, ib, _] = lut_index ++ [0]
        {disp_index, _} = List.pop_at(state.disp, i)
        [r, g, b, _] = disp_index ++ [0]

        acc
        |> List.replace_at(ir, r)
        |> List.replace_at(ig, g)
        |> List.replace_at(ib, b)
      end)

    Enum.map([state.left_matrix, state.right_matrix], fn {device, pin, offset} ->
      xfer(
        device,
        pin,
        <<@cmd_write_display, 0x00>> <>
          :erlang.list_to_binary(Enum.slice(buf, Range.new(offset, offset + 28 * 8)))
      )

      {:ok}
    end)

    {:ok}
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

  @impl GenServer
  def handle_info({:set_pixel, {x, y, r, g, b}}, state) do
    offset = x * @rows + y
    # if self._rotation == 90:
    #     y = _COLS - 1 - y
    #     offset = (y * _ROWS) + x
    # if self._rotation == 180:
    #     x = _COLS - 1 - x
    #     y = _ROWS - 1 - y
    #     offset = (x * _ROWS) + y
    # if self._rotation == 270:
    #     x = _ROWS - 1 - x
    #     offset = (y * _ROWS) + x
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
    xfer(
      state.left_matrix.device,
      state.left_matrix.pin,
      <<@cmd_global_brightness, round(Float.floor(63 * brightness))>>
    )

    xfer(
      state.right_matrix.device,
      state.right_matrix.pin,
      <<@cmd_global_brightness, round(Float.floor(63 * brightness))>>
    )
  end

  @impl GenServer
  def handle_info(:shutdown, state) do
    shutdown(state)
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

    show(state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(catch_all, state) do
    Logger.info(inspect(catch_all))
    {:noreply, state}
  end
end
