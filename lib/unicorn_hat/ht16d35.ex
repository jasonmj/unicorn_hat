defmodule UnicornHat.HT16D35 do
  @moduledoc File.read!("README.md")
             |> String.split(~r/<!-- DISPLAYDOC !-->/)
             |> Enum.drop(1)
             |> Enum.join("\n")

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

  def initialize_device({device, pin, offset}, buf) do
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

  def shutdown(state) do
    Enum.map([state.left_matrix, state.right_matrix], fn {device, pin, _offset} ->
      xfer(device, pin, <<@cmd_com_pin_ctrl, 0x00>>)
      xfer(device, pin, <<@cmd_row_pin_ctrl, 0x00, 0x00, 0x00, 0x00>>)
      xfer(device, pin, <<@cmd_system_ctrl, 0x00>>)
    end)
  end

  defp xfer(device, _pin, command) do
    SPI.transfer(device, command)
  end

  def set_frame(state) do
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

  def set_brightness(brightness, state) do
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
end
