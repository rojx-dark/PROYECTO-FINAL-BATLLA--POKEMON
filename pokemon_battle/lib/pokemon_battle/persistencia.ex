defmodule PokemonBattle.Persistencia do
  @moduledoc """
  Módulo de persistencia: lectura y escritura de archivos JSON y battles.log.
  Todos los paths son relativos a la raíz del proyecto.
  """

  @trainers_path "data/trainers.json"
  @pokemon_path  "data/pokemon.json"
  @moves_path    "data/moves.json"
  @tienda_path   "data/tienda.json"
  @battles_log   "data/battles.log"

  # ─── Entrenadores ────────────────────────────────────────────────────────────

  @doc "Carga todos los entrenadores desde disco. Retorna una lista de mapas."
  def cargar_entrenadores do
    leer_json(@trainers_path, [])
  end

  @doc "Persiste la lista completa de entrenadores en disco."
  def guardar_entrenadores(entrenadores) do
    escribir_json(@trainers_path, entrenadores)
  end

  # ─── Pokémon base ────────────────────────────────────────────────────────────

  @doc "Carga el catálogo de especies base desde pokemon.json."
  def cargar_especies do
    leer_json(@pokemon_path, [])
  end

  # ─── Movimientos ─────────────────────────────────────────────────────────────

  @doc "Carga el pool de movimientos por tipo desde moves.json."
  def cargar_movimientos do
    leer_json(@moves_path, %{})
  end

  # ─── Tienda ──────────────────────────────────────────────────────────────────

  @doc "Carga la configuración de tipos de sobre desde tienda.json."
  def cargar_tienda do
    leer_json(@tienda_path, %{})
  end

  # ─── Batallas log ────────────────────────────────────────────────────────────

  @doc "Registra el resultado de una batalla en battles.log."
  def registrar_batalla(entrada) when is_map(entrada) do
    linea = Jason.encode!(entrada) <> "\n"
    File.write(@battles_log, linea, [:append])
  end

  @doc "Lee el historial de batallas."
  def leer_historial_batallas do
    case File.read(@battles_log) do
      {:ok, contenido} ->
        contenido
        |> String.split("\n", trim: true)
        |> Enum.map(&Jason.decode!/1)

      {:error, _} -> []
    end
  end

  # ─── Helpers privados ────────────────────────────────────────────────────────

  defp leer_json(path, default) do
    case File.read(path) do
      {:ok, contenido} ->
        case Jason.decode(contenido) do
          {:ok, data} -> data
          {:error, _} -> default
        end

      {:error, _} -> default
    end
  end

  defp escribir_json(path, data) do
    contenido = Jason.encode!(data, pretty: true)
    File.write!(path, contenido)
  end
end
