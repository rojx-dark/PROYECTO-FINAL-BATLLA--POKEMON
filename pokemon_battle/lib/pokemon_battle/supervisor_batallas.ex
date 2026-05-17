defmodule PokemonBattle.SupervisorBatallas do
  @moduledoc """
  DynamicSupervisor que gestiona los procesos de batalla e intercambio.
  Cada batalla y sala de intercambio vive en un proceso GenServer independiente.
  Una falla en una batalla no tumba el servidor completo.
  """
  use DynamicSupervisor

  def start_link(_opts),
    do: DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok),
    do: DynamicSupervisor.init(strategy: :one_for_one)

  @doc "Inicia una nueva batalla bajo este supervisor."
  def iniciar_batalla(config) do
    spec = {PokemonBattle.Batalla, config}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @doc "Inicia una nueva sala de intercambio bajo este supervisor."
  def iniciar_intercambio(config) do
    spec = {PokemonBattle.Intercambio, config}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @doc "Detiene un proceso hijo (batalla o intercambio) dado su pid."
  def detener(pid) when is_pid(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end
end
