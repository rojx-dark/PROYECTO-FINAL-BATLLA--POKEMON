defmodule PokemonBattle.Batalla do
  @moduledoc """
  GenServer que representa una sala de batalla activa (1v1).
  Cada batalla vive en su propio proceso, gestionado por SupervisorBatallas.
  Implementa turnos simultáneos, timeout, cambio automático de Pokémon
  y rendición inmediata.
  """
  use GenServer, restart: :temporary
  require Logger
  alias PokemonBattle.{MotorCombate, GestorEntrenadores, Persistencia}

  # (los tiempos se manejan en el estado como tiempo_turno)

  # ─── API pública ─────────────────────────────────────────────────────────────

  def start_link(config),
    do: GenServer.start_link(__MODULE__, config)

  def enviar_accion(pid, usuario, accion),
    do: GenServer.call(pid, {:accion, usuario, accion})

  def estado(pid) do
    try do
      GenServer.call(pid, :estado)
    catch
      :exit, _ -> {:error, :batalla_terminada}
    end
  end

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
      timer_ref:    nil,
      terminada:    false,
      ganador:      nil
    }

    Logger.info("[Batalla #{id}] Iniciada en nodo #{nodo} entre #{jugador1} y #{jugador2}")
    estado_con_timer = arrancar_timer(estado_inicial)
    {:ok, estado_con_timer}
  end

  # ─── Acciones de turno ───────────────────────────────────────────────────────

  @impl true
  def handle_call({:accion, _usuario, _accion}, _from, %{terminada: true} = estado) do
    {:reply, {:error, "La batalla ya terminó."}, estado}
  end

  # ── Rendición inmediata ──────────────────────────────────────────────────────
  @impl true
  def handle_call({:accion, usuario, :rendirse}, _from, estado) do
    cancelar_timer(estado)
    {ganador, perdedor} = if usuario == estado.jugador1 do
      {estado.jugador2, estado.jugador1}
    else
      {estado.jugador1, estado.jugador2}
    end

    estado_final = cerrar_batalla(estado, ganador, perdedor)
    {:stop, :normal, :ok, estado_final}
  end

  @impl true
  def handle_call({:accion, usuario, accion}, _from, estado) do
    cond do
      usuario == estado.jugador1 and estado.accion1 == nil ->
        estado_con_accion = %{estado | accion1: accion}
        resultado = quizas_resolver(estado_con_accion)
        maybe_stop(resultado)

      usuario == estado.jugador2 and estado.accion2 == nil ->
        estado_con_accion = %{estado | accion2: accion}
        resultado = quizas_resolver(estado_con_accion)
        maybe_stop(resultado)

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

    resultado = resolver_turno(estado_con_pasar)
    if resultado.terminada do
      {:stop, :normal, resultado}
    else
      {:noreply, resultado}
    end
  end

  # ─── Helper para detener o continuar ────────────────────────────────────────

  defp maybe_stop(%{terminada: true} = estado) do
    # Previously the GenServer stopped immediately, preventing the CLI from retrieving the final state.
    # Instead, we simply reply with the updated state and keep the process alive.
    {:reply, :ok, estado}
  end
  defp maybe_stop(estado) do
    {:reply, :ok, estado}
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

    {pokemon_primero, pokemon_segundo, accion_primero, accion_segundo, equipo_primero, equipo_segundo, _jugador_primero, _jugador_segundo} =
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
        estado_tras_primer_ataque
      else
        {estado_final, _fue_debilitado} = ejecutar_accion(estado_tras_primer_ataque, accion_segundo, pokemon_segundo, pokemon_primero, equipo_segundo, equipo_primero)
        estado_final
      end

    # Cambio automático de pokémon debilitados
    estado_con_cambios = auto_cambiar_pokemon(estado_tras_ambas_acciones)

    # Verificar si la batalla terminó
    case verificar_fin(estado_con_cambios) do
      {:fin, jugador_ganador, jugador_perdedor} ->
        cerrar_batalla(estado_con_cambios, jugador_ganador, jugador_perdedor)

      :continua ->
        %{estado_con_cambios |
          turno:   estado_con_cambios.turno + 1,
          accion1: nil,
          accion2: nil
        }
        |> arrancar_timer()
    end
  end

  defp ejecutar_accion(estado, :pasar, _pokemon_atacante, _pokemon_defensor, _equipo_atacante, _equipo_defensor) do
    {estado, false}
  end

  defp ejecutar_accion(estado, :rendirse, _pokemon_atacante, _pokemon_defensor, equipo_atacante, equipo_defensor) do
    jugador_que_se_rinde = if equipo_atacante == :equipo1, do: estado.jugador1, else: estado.jugador2
    jugador_ganador      = if equipo_defensor == :equipo1, do: estado.jugador1, else: estado.jugador2
    estado_cerrado = cerrar_batalla(estado, jugador_ganador, jugador_que_se_rinde)
    {estado_cerrado, false}
  end

  defp ejecutar_accion(estado, {:cambiar, id_nuevo_pokemon}, _pokemon_atacante, _pokemon_defensor, equipo_atacante, _equipo_defensor) do
    clave_activo = if equipo_atacante == :equipo1, do: :activo1, else: :activo2
    {Map.put(estado, clave_activo, id_nuevo_pokemon), false}
  end

  defp ejecutar_accion(estado, {:ataque, nombre_movimiento}, pokemon_atacante, pokemon_defensor, _equipo_atacante, equipo_defensor) do
    movimiento = Enum.find(pokemon_atacante.movimientos, fn mov -> mov.nombre == nombre_movimiento end)

    if movimiento do
      dano        = MotorCombate.calcular_dano(movimiento, pokemon_atacante, pokemon_defensor)
      nueva_salud = max(0, pokemon_defensor.salud - dano)

      estado_actualizado = actualizar_salud(estado, equipo_defensor, pokemon_defensor.id, nueva_salud)
      {estado_actualizado, nueva_salud == 0}
    else
      {estado, false}
    end
  end

  defp ejecutar_accion(estado, _accion_desconocida, _pokemon_a, _pokemon_d, _equipo_a, _equipo_d), do: {estado, false}

  # ─── Cambio automático de Pokémon debilitados ───────────────────────────────

  defp auto_cambiar_pokemon(estado) do
    estado
    |> auto_cambiar_para(:equipo1, :activo1)
    |> auto_cambiar_para(:equipo2, :activo2)
  end

  defp auto_cambiar_para(estado, clave_equipo, clave_activo) do
    equipo = Map.get(estado, clave_equipo)
    id_activo = Map.get(estado, clave_activo)
    pokemon_actual = Enum.find(equipo, &(&1.id == id_activo))

    if pokemon_actual != nil and pokemon_actual.salud <= 0 do
      # Buscar el siguiente pokémon vivo
      siguiente = Enum.find(equipo, fn p -> p.salud > 0 and p.id != id_activo end)
      if siguiente do
        Map.put(estado, clave_activo, siguiente.id)
      else
        # No hay más pokémon vivos, se queda igual (verificar_fin lo detectará)
        estado
      end
    else
      estado
    end
  end

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

    %{estado | terminada: true, ganador: jugador_ganador}
  end

  defp inicializar_equipo(lista_pokemon) do
    Enum.map(lista_pokemon, fn pokemon -> Map.put(pokemon, :salud, 100) end)
  end

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
