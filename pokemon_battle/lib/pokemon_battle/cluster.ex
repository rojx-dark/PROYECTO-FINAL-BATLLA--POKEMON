defmodule PokemonBattle.Cluster do
  @moduledoc """
  Gestión de nodos distribuidos.
  Asigna batallas a nodos disponibles en round-robin.
  Para ejecutar en 2 nodos:

    # Nodo 1:
    iex --name arena@localhost --cookie pokemon_secret -S mix

    # Nodo 2:
    iex --name arena2@localhost --cookie pokemon_secret -S mix
    > Node.connect(:"arena@localhost")
  """

  @doc """
  Retorna el nodo al que se debe asignar la siguiente batalla.
  Si hay otros nodos conectados, alterna entre ellos.
  Si no hay otros nodos, usa el nodo local.
  """
  def nodo_para_batalla do
    nodos = [Node.self() | Node.list()]
    Enum.random(nodos)
  end

  @doc "Lista todos los nodos conectados (incluyendo el local)."
  def nodos_disponibles do
    [Node.self() | Node.list()]
  end

  @doc """
  Conecta al nodo remoto indicado.
  Ejemplo: Cluster.conectar(:"arena2@localhost")
  """
  def conectar(nodo) do
    case Node.connect(nodo) do
      true ->
        IO.puts("[Cluster] Conectado a #{nodo}")
        :ok

      false ->
        IO.puts("[Cluster] No se pudo conectar a #{nodo}")
        :error

      :ignored ->
        IO.puts("[Cluster] Ya conectado a #{nodo}")
        :ok
    end
  end

  @doc "Muestra los nodos actualmente conectados."
  def estado_cluster do
    nodos = nodos_disponibles()
    IO.puts("Nodos en el cluster (#{length(nodos)}):")
    Enum.each(nodos, fn n -> IO.puts("  - #{n}") end)
  end
end
