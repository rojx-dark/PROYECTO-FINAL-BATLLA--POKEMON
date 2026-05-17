defmodule PokemonBattle.GestorSalas do
  @moduledoc """
  GenServer que mantiene el registro de salas de batalla disponibles
  y coordina la creación/unión de jugadores y el inicio de batallas.
  """
  use GenServer
  alias PokemonBattle.{SupervisorBatallas, GestorEntrenadores, Cluster}

  @id_prefix "S-"

  # ─── API pública ─────────────────────────────────────────────────────────────

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def listar_salas,
    do: GenServer.call(__MODULE__, :listar_salas)

  def crear_sala(usuario, tiempo_turno \\ 20),
    do: GenServer.call(__MODULE__, {:crear_sala, usuario, tiempo_turno})

  def unirse_sala(usuario, id_sala),
    do: GenServer.call(__MODULE__, {:unirse_sala, usuario, id_sala})

  def iniciar_batalla(id_sala, usuario),
    do: GenServer.call(__MODULE__, {:iniciar_batalla, id_sala, usuario})

  def enviar_accion(usuario, accion),
    do: GenServer.call(__MODULE__, {:enviar_accion, usuario, accion})

  def sala_de(usuario),
    do: GenServer.call(__MODULE__, {:sala_de, usuario})

  # ─── Callbacks GenServer ─────────────────────────────────────────────────────

  @impl true
  def init(:ok), do: {:ok, %{salas: %{}, contador: 1000, jugador_sala: %{}}}

  @impl true
  def handle_call(:listar_salas, _from, estado) do
    if map_size(estado.salas) == 0 do
      IO.puts("No hay salas disponibles. Crea una con: crear_sala [tiempo_turno=N]")
    else
      IO.puts("=== Salas de Batalla ===")

      Enum.each(estado.salas, fn {id_sala, sala} ->
        nombres_jugadores = Enum.join(sala.jugadores, " vs ")
        estado_sala       = if sala.batalla_pid, do: "en curso", else: "esperando jugador"
        IO.puts("  #{id_sala} | Turno: #{sala.tiempo_turno}s | Jugadores: #{nombres_jugadores} | Estado: #{estado_sala}")
      end)
    end

    {:reply, :ok, estado}
  end

  @impl true
  def handle_call({:crear_sala, usuario, tiempo_turno}, _from, estado) do
    id_sala = "#{@id_prefix}#{estado.contador}"
    nueva_sala = %{
      id:           id_sala,
      jugadores:    [usuario],
      tiempo_turno: tiempo_turno,
      batalla_pid:  nil
    }
    nuevo_estado = %{estado |
      salas:        Map.put(estado.salas, id_sala, nueva_sala),
      contador:     estado.contador + 1,
      jugador_sala: Map.put(estado.jugador_sala, usuario, id_sala)
    }
    IO.puts("[OK] Sala #{id_sala} creada. Tiempo de turno: #{tiempo_turno}s. Esperando rival...")
    {:reply, {:ok, id_sala}, nuevo_estado}
  end

  @impl true
  def handle_call({:unirse_sala, usuario, id_sala}, _from, estado) do
    case Map.get(estado.salas, id_sala) do
      nil ->
        IO.puts("[Error] Sala #{id_sala} no existe.")
        {:reply, :error, estado}

      %{jugadores: jugadores_actuales} when length(jugadores_actuales) >= 2 ->
        IO.puts("[Error] La sala #{id_sala} ya tiene 2 jugadores.")
        {:reply, :error, estado}

      sala ->
        sala_actualizada = %{sala | jugadores: sala.jugadores ++ [usuario]}
        nuevo_estado = %{estado |
          salas:        Map.put(estado.salas, id_sala, sala_actualizada),
          jugador_sala: Map.put(estado.jugador_sala, usuario, id_sala)
        }
        IO.puts("[Sala #{id_sala}] #{usuario} se ha unido. ¡Listos para la batalla!")
        {:reply, :ok, nuevo_estado}
    end
  end

  @impl true
  def handle_call({:iniciar_batalla, id_sala, _usuario}, _from, estado) do
    case Map.get(estado.salas, id_sala) do
      nil ->
        IO.puts("[Error] Sala #{id_sala} no existe.")
        {:reply, :error, estado}

      %{jugadores: [jugador1, jugador2], batalla_pid: nil} = sala ->
        equipo_jugador1 = GestorEntrenadores.get_equipo_activo(jugador1)
        equipo_jugador2 = GestorEntrenadores.get_equipo_activo(jugador2)

        cond do
          equipo_jugador1 == nil or equipo_jugador1 == [] ->
            IO.puts("[Error] #{jugador1} no tiene equipo cargado. Usa: usar_equipo <nombre>")
            {:reply, :error, estado}

          equipo_jugador2 == nil or equipo_jugador2 == [] ->
            IO.puts("[Error] #{jugador2} no tiene equipo cargado. Usa: usar_equipo <nombre>")
            {:reply, :error, estado}

          true ->
            nodo_asignado = Cluster.nodo_para_batalla()
            config_batalla = %{
              id:           id_sala,
              jugador1:     jugador1,
              jugador2:     jugador2,
              tiempo_turno: sala.tiempo_turno,
              nodo:         nodo_asignado
            }

            {:ok, pid_batalla} = SupervisorBatallas.iniciar_batalla(config_batalla)
            sala_actualizada   = %{sala | batalla_pid: pid_batalla}
            nuevo_estado       = %{estado | salas: Map.put(estado.salas, id_sala, sala_actualizada)}
            IO.puts("[Batalla #{id_sala}] Iniciada en nodo #{nodo_asignado} entre #{jugador1} y #{jugador2}")
            {:reply, {:ok, pid_batalla}, nuevo_estado}
        end

      %{jugadores: jugadores_actuales} when length(jugadores_actuales) < 2 ->
        IO.puts("[Error] Se necesitan 2 jugadores para iniciar la batalla.")
        {:reply, :error, estado}

      _ ->
        IO.puts("[Error] La batalla ya está en curso.")
        {:reply, :error, estado}
    end
  end

  @impl true
  def handle_call({:enviar_accion, usuario, accion}, _from, estado) do
    case Map.get(estado.jugador_sala, usuario) do
      nil ->
        IO.puts("[Error] No estás en ninguna sala de batalla.")
        {:reply, :error, estado}

      id_sala ->
        case Map.get(estado.salas, id_sala) do
          %{batalla_pid: pid_batalla} when is_pid(pid_batalla) ->
            resultado = PokemonBattle.Batalla.enviar_accion(pid_batalla, usuario, accion)
            {:reply, resultado, estado}

          _ ->
            IO.puts("[Error] La batalla no ha iniciado aún.")
            {:reply, :error, estado}
        end
    end
  end

  @impl true
  def handle_call({:sala_de, usuario}, _from, estado) do
    {:reply, Map.get(estado.jugador_sala, usuario), estado}
  end
end
