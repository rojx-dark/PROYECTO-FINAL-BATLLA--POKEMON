defmodule PokemonBattle.Application do
  @moduledoc """
  Punto de entrada OTP de la aplicación PokemonBattle.
  Arranca el árbol de supervisión principal.
  """
  use Application

  @impl true
  def start(_type, _args) do
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
