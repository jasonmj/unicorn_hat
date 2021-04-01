defmodule UnicornHat.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: UnicornHat.Supervisor]

    children =
      [
        # Children for all targets
      ] ++ children(target())

    Supervisor.start_link(children, opts)
  end

  def children(:host) do
    [
      # Children for host only
    ]
  end

  def children(_target) do
    if Application.get_env(:unicorn_hat, :env) == :dev do
      System.cmd("epmd", ["-daemon"])
      Node.start(:"app@unicorn.local")
      Node.set_cookie(Application.get_env(:mix_tasks_upload_hotswap, :cookie))
    end

    [
      # Children for targets only
      UnicornHat.Hat
    ]
  end

  def target() do
    Application.get_env(:unicorn_hat, :target)
  end
end
