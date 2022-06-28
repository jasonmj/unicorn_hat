defmodule UnicornHat.HT16D35 do
  @moduledoc """
  The hardware communication layer for the Holtek HT16D35.
  """

  alias Circuits.SPI
  alias UnicornHat.HT16D35.LookupTable

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
    transfer(device, pin, <<@cmd_soft_reset>>)
    transfer(device, pin, <<@cmd_global_brightness, 0x01>>)
    transfer(device, pin, <<@cmd_scroll_ctrl, 0x00>>)
    transfer(device, pin, <<@cmd_system_ctrl, 0x00>>)

    transfer(
      device,
      pin,
      <<@cmd_write_display, 0x00>> <>
        :erlang.list_to_binary(Enum.slice(buf, Range.new(offset, offset + 28 * 8)))
    )

    transfer(device, pin, <<@cmd_com_pin_ctrl, 0xFF>>)
    transfer(device, pin, <<@cmd_row_pin_ctrl, 0xFF, 0xFF, 0xFF, 0xFF>>)
    transfer(device, pin, <<@cmd_system_ctrl, 0x03>>)
  end

  def shutdown(left_matrix, right_matrix) do
    Enum.map([left_matrix, right_matrix], fn {device, pin, _offset} ->
      transfer(device, pin, <<@cmd_com_pin_ctrl, 0x00>>)
      transfer(device, pin, <<@cmd_row_pin_ctrl, 0x00, 0x00, 0x00, 0x00>>)
      transfer(device, pin, <<@cmd_system_ctrl, 0x00>>)
    end)
  end

  def set_frame(buf, disp, left_matrix, right_matrix) do
    buf =
      Enum.reduce(Range.new(1, @cols * @rows - 1), buf, fn i, acc ->
        {lut_index, _} = List.pop_at(LookupTable.get(), i)
        [ir, ig, ib, _] = lut_index ++ [0]
        {disp_index, _} = List.pop_at(disp, i)
        [r, g, b, _] = disp_index ++ [0]

        acc
        |> List.replace_at(ir, r)
        |> List.replace_at(ig, g)
        |> List.replace_at(ib, b)
      end)

    Enum.map([left_matrix, right_matrix], fn {device, pin, offset} ->
      transfer(
        device,
        pin,
        <<@cmd_write_display, 0x00>> <>
          :erlang.list_to_binary(Enum.slice(buf, Range.new(offset, offset + 28 * 8)))
      )
    end)
  end

  def set_brightness(brightness, left_matrix, right_matrix) do
    transfer(
      left_matrix.device,
      left_matrix.pin,
      <<@cmd_global_brightness, round(Float.floor(63 * brightness))>>
    )

    transfer(
      right_matrix.device,
      right_matrix.pin,
      <<@cmd_global_brightness, round(Float.floor(63 * brightness))>>
    )
  end

  defp transfer(device, _pin, command) do
    SPI.transfer(device, command)
  end
end
