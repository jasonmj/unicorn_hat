# UnicornHat

An Elixir Nerves implementation of the Pimoroni [Unicorn Hat Mini](https://shop.pimoroni.com/products/unicorn-hat-mini).

Based on the official Pimoroni library: [pimoroni/unicornhatmini-python](https://github.com/pimoroni/unicornhatmini-python/).

And a similar Pimoroni product & Elixir library: [jjcarstens/scroll_hat](https://github.com/jjcarstens/scroll_hat).

## Usage
The main interface is via the `UnicornHat.Display`.

<!-- DISPLAYDOC !-->
`UnicornHat.Display` interacts with the HT16D35 RGB LED driver. To use it, you need to either add it to your supervision tree with a child spec like `UnicornHat.Display` or start it manually:

```elixir
{:ok, _pid} = UnicornHat.Display.start_link()
```

After the `UnicornHat.Display` GenServer has started, you can use a few basic commands to control it:

```elixir
alias UnicornHat.Display

# Set all the LEDS in the display buffer to the specified RGB color combination
Display.set_all(0, 0, 255)

# Transfer the current display buffer to the device
Display.show()

# Clear the dislay buffer and update the device
Display.clear()
Display.show()

# Set the brightness for the display
Display.set_brightness(255)

# Set the rotation for the display to one of 0, 90, 180, or 270 degrees
Display.set_rotation(90)

# Set the specified pixel to the specified RGB color combination
Display.set_pixel(0, 0, 255, 255, 255)
Display.show()

# Turn off the display
Display.shutdown()
```

<!-- DISPLAYDOC !-->

This library also features a GenServer module for interfacing with the onboard buttons included in the Unicorn Hat Mini.

<!-- BUTTONSDOC !-->

The Unicorn Hat mini has 4 buttons that are monitored independently from the display
and can be started in supervison.

Supply the `:handler` option as either a pid, or `{module, function, args}` tuple
specifying when to send events to. If no handler is supplied, events are simply logged

```elixir
UnicornHat.Buttons.start_link(handler: self())
```

You can also query the current value of a button at any time

```elixir
UnicornHat.Buttons.get_value(:a)
```

<!-- BUTTONSDOC !-->

## Targets

Nerves applications produce images for hardware targets based on the
`MIX_TARGET` environment variable. If `MIX_TARGET` is unset, `mix` builds an
image that runs on the host (e.g., your laptop). This is useful for executing
logic tests, running utilities, and debugging. Other targets are represented by
a short name like `rpi3` that maps to a Nerves system image for that platform.
All of this logic is in the generated `mix.exs` and may be customized. For more
information about targets see:

https://hexdocs.pm/nerves/targets.html#content

## Getting Started

To start your Nerves app:
  * `export MIX_TARGET=my_target` or prefix every command with
    `MIX_TARGET=my_target`. For example, `MIX_TARGET=rpi3`
  * Install dependencies with `mix deps.get`
  * Create firmware with `mix firmware`
  * Burn to an SD card with `mix firmware.burn`

## Learn more

  * Official docs: https://hexdocs.pm/nerves/getting-started.html
  * Official website: https://nerves-project.org/
  * Forum: https://elixirforum.com/c/nerves-forum
  * Discussion Slack elixir-lang #nerves ([Invite](https://elixir-slackin.herokuapp.com/))
  * Source: https://github.com/nerves-project/nerves
