defmodule UnicornHat.Buttons do
  @moduledoc """
  Buttons interface for Unicorn Hat Mini

  Pass a `:handler` option as a pid or {m, f, a} to receive the button events
  """
  # use GenServer

  # alias Circuits.GPIO

  # require Logger

  # @typedoc """
  # A name of Scroll HAT Mini button

  # These are labelled A, B, X, and Y on the board.
  # """
  # @type name() :: :a | :b | :x | :y

  # defmodule Event do
  #   defstruct [:action, :name, :value, :timestamp]

  #   @type t :: %Event{
  #           action: :pressed | :released,
  #           name: Buttons.name(),
  #           value: 1 | 0,
  #           timestamp: non_neg_integer()
  #         }
  # end

  # @pin_a 5
  # @pin_b 6
  # @pin_x 16
  # @pin_y 24

  # @doc """
  # Start a GenServer to watch the buttons on the Scroll HAT Mini

  # Options:

  # * `:handler` - pass a pid or an MFA to receive button events
  # """
  # @spec start_link(keyword) :: GenServer.on_start()
  # def start_link(opts \\ []) do
  #   GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  # end

  # @doc """
  # Return the current state of the button

  # `0` - released
  # `1` - pressed
  # """
  # @spec get_value(name()) :: 0 | 1
  # def get_value(button) do
  #   GenServer.call(__MODULE__, {:get_value, button})
  # end

  # @impl GenServer
  # def init(opts) do
  #   {:ok, %{button_to_ref: %{}, pin_to_button: %{}, handler: opts[:handler]}, {:continue, :init}}
  # end

  # @impl GenServer
  # def handle_continue(:init, state) do
  #   {:ok, a} = GPIO.open(@pin_a, :input, pull_mode: :pullup)
  #   {:ok, b} = GPIO.open(@pin_b, :input, pull_mode: :pullup)
  #   {:ok, x} = GPIO.open(@pin_x, :input, pull_mode: :pullup)
  #   {:ok, y} = GPIO.open(@pin_y, :input, pull_mode: :pullup)
  #   :ok = GPIO.set_interrupts(a, :both)
  #   :ok = GPIO.set_interrupts(b, :both)
  #   :ok = GPIO.set_interrupts(x, :both)
  #   :ok = GPIO.set_interrupts(y, :both)

  #   button_to_ref = %{a: a, b: b, x: x, y: y}

  #   pin_to_button = %{
  #     @pin_a => :a,
  #     @pin_b => :b,
  #     @pin_x => :x,
  #     @pin_y => :y
  #   }

  #   {:noreply, %{state | button_to_ref: button_to_ref, pin_to_button: pin_to_button}}
  # end

  # @impl GenServer
  # def handle_call({:get_value, name}, _from, state) do
  #   inverted_value = GPIO.read(state.button_to_ref[name])
  #   value = 1 - inverted_value

  #   {:reply, value, state}
  # end

  # @impl GenServer
  # def handle_info({:circuits_gpio, pin, timestamp, inverted_value}, state) do
  #   value = 1 - inverted_value
  #   action = if value != 0, do: :pressed, else: :released

  #   event = %Event{
  #     action: action,
  #     name: state.pin_to_button[pin],
  #     value: value,
  #     timestamp: timestamp
  #   }

  #   _ = send_event(state.handler, event)

  #   {:noreply, state}
  # end

  # def handle_info(_other, state), do: {:noreply, state}

  # defp send_event(handler, event) when is_pid(handler), do: send(handler, event)

  # defp send_event({m, f, a}, event) when is_atom(m) and is_atom(f) and is_list(a) do
  #   apply(m, f, [event | a])
  # end

  # defp send_event(_, event) do
  #   Logger.info("[ScrollHat] unhandled button event - #{inspect(event)}")
  # end
end
