defmodule PokemonBattle.Batalla do
  @moduledoc """
  GenServer que representa una sala de batalla activa (1v1).
  Cada batalla vive en su propio proceso, gestionado por SupervisorBatallas.
  Implementa turnos simultáneos, timeout y lógica de combate.
  """
  use GenServer, restart: :temporary
  require Logger
  alias PokemonBattle.{MotorCombate, GestorEntrenadores, Persistencia}

  @timeout_turno_ms    20_000
  @timeout_abandono_ms 15_000

  # ─── API pública ─────────────────────────────────────────────────────────────

  def start_link(config),
    do: GenServer.start_link(__MODULE__, config)

  def enviar_accion(pid, usuario, accion),
    do: GenServer.call(pid, {:accion, usuario, accion})

  def estado(pid),
    do: GenServer.call(pid, :estado)

  # ─── Init ────────────────────────────────────────────────────────────────────

  @impl true
  def init(%{id: id, jugador1: jugador1, jugador2: jugador2, tiempo_turno: tiempo_turno, nodo: nodo}) do
    equipo1 = GestorEntrenadores.get_equipo_activo(jugador1)
    equipo2 = GestorEntrenadores.get_equipo_activo(jugador2)

    estado_inicial = %{
      id:           id,
      nodo:         nodo,
      jugador1:     jugador1,
      jugador2:     jugador2,
      equipo1:      inicializar_equipo(equipo1),
      equipo2:      inicializar_equipo(equipo2),
      activo1:      hd(equipo1).id,
      activo2:      hd(equipo2).id,
      turno:        1,
      accion1:      nil,
      accion2:      nil,
      tiempo_turno: tiempo_turno,
      inicio:       DateTime.utc_now(),
      timer_ref:    nil
    }

    Logger.info("[Batalla #{id}] Iniciada en nodo #{nodo} entre #{jugador1} y #{jugador2}")
    estado_con_timer = arrancar_timer(estado_inicial)
    mostrar_turno(estado_con_timer)
    {:ok, estado_con_timer}
  end

  # ─── Acciones de turno ───────────────────────────────────────────────────────

  @impl true
  def handle_call({:accion, usuario, accion}, _from, estado) do
    cond do
      usuario == estado.jugador1 and estado.accion1 == nil ->
        estado_con_accion = %{estado | accion1: accion}
        {:reply, :ok, quizas_resolver(estado_con_accion)}

      usuario == estado.jugador2 and estado.accion2 == nil ->
        estado_con_accion = %{estado | accion2: accion}
        {:reply, :ok, quizas_resolver(estado_con_accion)}

      true ->
        {:reply, {:error, "Ya enviaste tu acción este turno."}, estado}
    end
  end

  @impl true
  def handle_call(:estado, _from, estado), do: {:reply, estado, estado}

  # ─── Timeout de turno ────────────────────────────────────────────────────────

  @impl true
  def handle_info(:timeout_turno, estado) do
    Logger.info("[Batalla #{estado.id}] Timeout de turno #{estado.turno}")

    # Si algún jugador no actuó, su acción es :pasar
    estado_con_pasar = %{estado |
      accion1: estado.accion1 || :pasar,
      accion2: estado.accion2 || :pasar
    }

    {:noreply, resolver_turno(estado_con_pasar)}
  end

  # ─── Resolución de turno ─────────────────────────────────────────────────────

  defp quizas_resolver(%{accion1: nil} = estado), do: estado
  defp quizas_resolver(%{accion2: nil} = estado), do: estado
  defp quizas_resolver(estado) do
    cancelar_timer(estado)
    resolver_turno(estado)
  end

  defp resolver_turno(estado) do
    pokemon1 = pokemon_activo(estado.equipo1, estado.activo1)
    pokemon2 = pokemon_activo(estado.equipo2, estado.activo2)

    {pokemon_primero, pokemon_segundo, accion_primero, accion_segundo, equipo_primero, equipo_segundo, _jugador_primero, jugador_segundo} =
      case MotorCombate.orden_por_velocidad(pokemon1, pokemon2) do
        {^pokemon1, ^pokemon2} ->
          {pokemon1, pokemon2, estado.accion1, estado.accion2, :equipo1, :equipo2, estado.jugador1, estado.jugador2}
        {^pokemon2, ^pokemon1} ->
          {pokemon2, pokemon1, estado.accion2, estado.accion1, :equipo2, :equipo1, estado.jugador2, estado.jugador1}
      end

    # Ejecutar acción del pokemon más rápido primero
    {estado_tras_primer_ataque, pokemon_segundo_debilitado?} =
      ejecutar_accion(estado, accion_primero, pokemon_primero, pokemon_segundo, equipo_primero, equipo_segundo)

    # Ejecutar acción del segundo solo si su pokémon no fue debilitado
    estado_tras_ambas_acciones =
      if pokemon_segundo_debilitado? do
        IO.puts("[#{jugador_segundo}] Tu Pokémon fue debilitado antes de actuar este turno.")
        estado_tras_primer_ataque
      else
        {estado_final, _fue_debilitado} = ejecutar_accion(estado_tras_primer_ataque, accion_segundo, pokemon_segundo, pokemon_primero, equipo_segundo, equipo_primero)
        estado_final
      end

    # Verificar si la batalla terminó
    case verificar_fin(estado_tras_ambas_acciones) do
      {:fin, jugador_ganador, jugador_perdedor} ->
        cerrar_batalla(estado_tras_ambas_acciones, jugador_ganador, jugador_perdedor)

      :continua ->
        estado_siguiente_turno = %{estado_tras_ambas_acciones |
          turno:   estado_tras_ambas_acciones.turno + 1,
          accion1: nil,
          accion2: nil
        }
        estado_con_nuevo_timer = arrancar_timer(estado_siguiente_turno)
        mostrar_turno(estado_con_nuevo_timer)
        estado_con_nuevo_timer
    end
  end

  defp ejecutar_accion(estado, :pasar, _pokemon_atacante, _pokemon_defensor, _equipo_atacante, _equipo_defensor) do
    {estado, false}
  end

  defp ejecutar_accion(estado, :rendirse, _pokemon_atacante, _pokemon_defensor, equipo_atacante, equipo_defensor) do
    jugador_que_se_rinde = if equipo_atacante == :equipo1, do: estado.jugador1, else: estado.jugador2
    jugador_ganador      = if equipo_defensor == :equipo1, do: estado.jugador1, else: estado.jugador2
    IO.puts("[Batalla #{estado.id}] #{jugador_que_se_rinde} se rinde. #{jugador_ganador} gana.")
    estado_cerrado = cerrar_batalla(estado, jugador_ganador, jugador_que_se_rinde)
    {estado_cerrado, false}
  end

  defp ejecutar_accion(estado, {:cambiar, id_nuevo_pokemon}, _pokemon_atacante, _pokemon_defensor, equipo_atacante, _equipo_defensor) do
    clave_activo = if equipo_atacante == :equipo1, do: :activo1, else: :activo2
    IO.puts("[Cambio] Pokémon activo cambiado a ##{id_nuevo_pokemon}")
    {Map.put(estado, clave_activo, id_nuevo_pokemon), false}
  end

  defp ejecutar_accion(estado, {:ataque, nombre_movimiento}, pokemon_atacante, pokemon_defensor, _equipo_atacante, equipo_defensor) do
    movimiento = Enum.find(pokemon_atacante.movimientos, fn mov -> mov.nombre == nombre_movimiento end)

    if movimiento do
      dano        = MotorCombate.calcular_dano(movimiento, pokemon_atacante, pokemon_defensor)
      nueva_salud = max(0, pokemon_defensor.salud - dano)
      IO.puts("  [#{String.capitalize(pokemon_atacante.especie)}] usa #{nombre_movimiento} → #{dano} de daño a #{String.capitalize(pokemon_defensor.especie)} (Salud: #{nueva_salud}/100)")

      estado_actualizado = actualizar_salud(estado, equipo_defensor, pokemon_defensor.id, nueva_salud)
      {estado_actualizado, nueva_salud == 0}
    else
      IO.puts("[Error] Movimiento '#{nombre_movimiento}' no pertenece a #{String.capitalize(pokemon_atacante.especie)}.")
      {estado, false}
    end
  end

  defp ejecutar_accion(estado, _accion_desconocida, _pokemon_a, _pokemon_d, _equipo_a, _equipo_d), do: {estado, false}

  # ─── Helpers ────────────────────────────────────────────────────────────────

  defp pokemon_activo(equipo, id_buscado), do: Enum.find(equipo, &(&1.id == id_buscado))

  defp actualizar_salud(estado, clave_equipo, id_pokemon, nueva_salud) do
    equipo_actualizado =
      Map.get(estado, clave_equipo)
      |> Enum.map(fn pokemon ->
        if pokemon.id == id_pokemon, do: %{pokemon | salud: nueva_salud}, else: pokemon
      end)
    Map.put(estado, clave_equipo, equipo_actualizado)
  end

  defp verificar_fin(estado) do
    vivos_equipo1 = Enum.count(estado.equipo1, fn pokemon -> pokemon.salud > 0 end)
    vivos_equipo2 = Enum.count(estado.equipo2, fn pokemon -> pokemon.salud > 0 end)

    cond do
      vivos_equipo1 == 0 -> {:fin, estado.jugador2, estado.jugador1}
      vivos_equipo2 == 0 -> {:fin, estado.jugador1, estado.jugador2}
      true               -> :continua
    end
  end

  defp cerrar_batalla(estado, jugador_ganador, jugador_perdedor) do
    duracion_segundos = DateTime.diff(DateTime.utc_now(), estado.inicio)

    IO.puts("""
    ═══════════════════════════════
    ¡Batalla terminada!
    Ganador: #{jugador_ganador} | Turnos: #{estado.turno} | Nodo: #{estado.nodo}
    #{jugador_ganador} recibe +100 monedas | #{jugador_perdedor} recibe +30 monedas
    ═══════════════════════════════
    """)

    GestorEntrenadores.recompensar_batalla(jugador_ganador, jugador_perdedor)

    Persistencia.registrar_batalla(%{
      fecha:    DateTime.to_iso8601(DateTime.utc_now()),
      jugador1: estado.jugador1,
      jugador2: estado.jugador2,
      ganador:  jugador_ganador,
      nodo:     to_string(estado.nodo),
      duracion: duracion_segundos,
      turnos:   estado.turno
    })

    estado
  end

  defp inicializar_equipo(lista_pokemon) do
    Enum.map(lista_pokemon, fn pokemon -> Map.put(pokemon, :salud, 100) end)
  end

  defp mostrar_turno(estado) do
    pokemon1 = pokemon_activo(estado.equipo1, estado.activo1)
    pokemon2 = pokemon_activo(estado.equipo2, estado.activo2)

    MotorCombate.mostrar_estado_turno(
      estado.turno,
      pokemon1, Enum.map(estado.equipo1, &marcar_activo(&1, estado.activo1)),
      pokemon2, Enum.map(estado.equipo2, &marcar_activo(&1, estado.activo2))
    )
  end

  defp marcar_activo(pokemon, id_activo), do: Map.put(pokemon, :activo, pokemon.id == id_activo)

  defp arrancar_timer(estado) do
    referencia_timer = Process.send_after(self(), :timeout_turno, estado.tiempo_turno * 1_000)
    %{estado | timer_ref: referencia_timer}
  end

  defp cancelar_timer(%{timer_ref: nil} = estado), do: estado
  defp cancelar_timer(%{timer_ref: referencia_timer} = estado) do
    Process.cancel_timer(referencia_timer)
    %{estado | timer_ref: nil}
  end
end
