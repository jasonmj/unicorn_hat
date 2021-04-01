defmodule UnicornHat.Hat do
  require Logger
  use GenServer
  use Bitwise
  alias Circuits.SPI

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

  # @button_a 5
  # @button_b 6
  # @button_x 16
  # @button_y 20

  @lut [
    [139, 138, 137],
    [223, 222, 221],
    [167, 166, 165],
    [195, 194, 193],
    [111, 110, 109],
    [55, 54, 53],
    [83, 82, 81],
    [136, 135, 134],
    [220, 219, 218],
    [164, 163, 162],
    [192, 191, 190],
    [108, 107, 106],
    [52, 51, 50],
    [80, 79, 78],
    [113, 115, 114],
    [197, 199, 198],
    [141, 143, 142],
    [169, 171, 170],
    [85, 87, 86],
    [29, 31, 30],
    [57, 59, 58],
    [116, 118, 117],
    [200, 202, 201],
    [144, 146, 145],
    [172, 174, 173],
    [88, 90, 89],
    [32, 34, 33],
    [60, 62, 61],
    [119, 121, 120],
    [203, 205, 204],
    [147, 149, 148],
    [175, 177, 176],
    [91, 93, 92],
    [35, 37, 36],
    [63, 65, 64],
    [122, 124, 123],
    [206, 208, 207],
    [150, 152, 151],
    [178, 180, 179],
    [94, 96, 95],
    [38, 40, 39],
    [66, 68, 67],
    [125, 127, 126],
    [209, 211, 210],
    [153, 155, 154],
    [181, 183, 182],
    [97, 99, 98],
    [41, 43, 42],
    [69, 71, 70],
    [128, 130, 129],
    [212, 214, 213],
    [156, 158, 157],
    [184, 186, 185],
    [100, 102, 101],
    [44, 46, 45],
    [72, 74, 73],
    [131, 133, 132],
    [215, 217, 216],
    [159, 161, 160],
    [187, 189, 188],
    [103, 105, 104],
    [47, 49, 48],
    [75, 77, 76],
    [363, 362, 361],
    [447, 446, 445],
    [391, 390, 389],
    [419, 418, 417],
    [335, 334, 333],
    [279, 278, 277],
    [307, 306, 305],
    [360, 359, 358],
    [444, 443, 442],
    [388, 387, 386],
    [416, 415, 414],
    [332, 331, 330],
    [276, 275, 274],
    [304, 303, 302],
    [337, 339, 338],
    [421, 423, 422],
    [365, 367, 366],
    [393, 395, 394],
    [309, 311, 310],
    [253, 255, 254],
    [281, 283, 282],
    [340, 342, 341],
    [424, 426, 425],
    [368, 370, 369],
    [396, 398, 397],
    [312, 314, 313],
    [256, 258, 257],
    [284, 286, 285],
    [343, 345, 344],
    [427, 429, 428],
    [371, 373, 372],
    [399, 401, 400],
    [315, 317, 316],
    [259, 261, 260],
    [287, 289, 288],
    [346, 348, 347],
    [430, 432, 431],
    [374, 376, 375],
    [402, 404, 403],
    [318, 320, 319],
    [262, 264, 263],
    [290, 292, 291],
    [349, 351, 350],
    [433, 435, 434],
    [377, 379, 378],
    [405, 407, 406],
    [321, 323, 322],
    [265, 267, 266],
    [293, 295, 294],
    [352, 354, 353],
    [436, 438, 437],
    [380, 382, 381],
    [408, 410, 409],
    [324, 326, 325],
    [268, 270, 269],
    [296, 298, 297]
  ]

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

  defp xfer(device, _pin, command) do
    SPI.transfer(device, command)
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

  def show(state) do
    buf =
      Enum.reduce(Range.new(1, @cols * @rows - 1), state.buf, fn i, acc ->
        {lut_index, _} = List.pop_at(@lut, i)
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
