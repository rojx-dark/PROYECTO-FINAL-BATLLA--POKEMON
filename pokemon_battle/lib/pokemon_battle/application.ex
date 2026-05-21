defmodule PokemonBattle.Application do
  @moduledoc """
  Punto de entrada OTP de la aplicación PokemonBattle.
  Arranca el árbol de supervisión principal.
  """
  use Application

  @impl true
  def start(_type, _args) do
    # Iniciar automáticamente el nodo distributed si no está vivo
    if Node.alive?() == false do
      case Node.start(:"servidor@127.0.0.1") do
        {:ok, _pid} ->
          Node.set_cookie(:intercambio_secreto)
          IO.puts("\n[Cluster] Nodo iniciado automáticamente como servidor@127.0.0.1 con cookie :intercambio_secreto")
        {:error, razon} ->
          IO.puts("\n[Cluster] Advertencia: No se pudo iniciar el nodo distribuido automáticamente: #{inspect(razon)}")
      end
    end

    children = [
      # Supervisor de batallas (DynamicSupervisor)
      {PokemonBattle.SupervisorBatallas, []},
      # Gestor de entrenadores (GenServer global con estado en memoria)
      {PokemonBattle.GestorEntrenadores, []},
      # Gestor de salas de batalla
      {PokemonBattle.GestorSalas, []},
      # Servidor de interfaz de comandos
      {PokemonBattle.Servidor, []}
    ]

    opts = [strategy: :one_for_one, name: PokemonBattle.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
