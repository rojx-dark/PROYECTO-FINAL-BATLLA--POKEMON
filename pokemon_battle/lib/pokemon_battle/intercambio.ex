defmodule PokemonBattle.Intercambio do
  @moduledoc """
  GenServer de sala de intercambio en tiempo real.
  Cada sala vive en su propio proceso bajo SupervisorBatallas.
  Si cualquiera de los dos se desconecta, la sala se cancela.
  """
  use GenServer, restart: :temporary
  alias PokemonBattle.{SupervisorBatallas, GestorEntrenadores}

  @id_prefix "IC-"

  @timeout_creacion 60_000 # 60 segundos
  @timeout_activo 120_000   # 120 segundos

  # Registro ETS de salas activas: {codigo -> pid}
  @tabla_intercambios :intercambios_activos

  # ─── API pública ─────────────────────────────────────────────────────────────

  def crear_sala(usuario) do
    codigo = generar_codigo()
    config = %{codigo: codigo, creador: usuario}
    {:ok, _pid} = SupervisorBatallas.iniciar_intercambio(config)
    IO.puts("[Sala #{codigo} creada] Comparte este código con el otro entrenador. Expirará en 60 segundos si nadie se une.")
    {:ok, codigo}
  end

  def listar_intercambios do
    if :ets.whereis(@tabla_intercambios) != :undefined do
      salas = :ets.tab2list(@tabla_intercambios)
      if salas == [] do
        IO.puts("No hay salas de intercambio activas.")
      else
        IO.puts("=== Salas de Intercambio Activas ===")
        Enum.each(salas, fn {codigo, pid} ->
          estado = try do
            GenServer.call(pid, :get_estado, 500)
          catch
            :exit, _ -> nil
          end
          case estado do
            nil -> IO.puts("  #{codigo} - (no responde)")
            %{creador: creador, invitado: invitado, oferta: oferta} ->
              invitado_str = if invitado, do: invitado, else: "?"
              IO.puts("  #{codigo} | Creador: #{creador} | Invitado: #{invitado_str} | Ofertas: #{map_size(oferta)}")
          end
        end)
      end
    else
      IO.puts("ETS de intercambio no inicializado.")
    end
  end

  def unirse_sala(usuario, codigo) do
    case buscar_sala(codigo) do
      nil ->
        IO.puts("[Error] Sala #{codigo} no existe o ya expiró.")

      pid_sala ->
        GenServer.call(pid_sala, {:unirse, usuario})
    end
  end

  def ofrecer_pokemon(usuario, id_pokemon) do
    case sala_del_usuario(usuario) do
      nil      -> IO.puts("[Error] No estás en ninguna sala de intercambio o ya expiró.")
      pid_sala -> GenServer.call(pid_sala, {:ofrecer, usuario, id_pokemon})
    end
  end

  def confirmar_intercambio(usuario) do
    case sala_del_usuario(usuario) do
      nil      -> IO.puts("[Error] No estás en ninguna sala de intercambio o ya expiró.")
      pid_sala -> GenServer.call(pid_sala, {:confirmar, usuario})
    end
  end

  def cancelar_intercambio(usuario) do
    case sala_del_usuario(usuario) do
      nil      -> IO.puts("[Error] No estás en ninguna sala de intercambio o ya expiró.")
      pid_sala -> GenServer.call(pid_sala, {:cancelar, usuario})
    end
  end

  # ─── GenServer callbacks ─────────────────────────────────────────────────────

  @impl true
  def init(%{codigo: codigo, creador: creador}) do
    asegurar_tabla()
    :ets.insert(@tabla_intercambios, {codigo, self()})

    # Iniciar temporizador de creación
    timer = Process.send_after(self(), :timeout_creacion, @timeout_creacion)

    estado = %{
      codigo:     codigo,
      creador:    creador,
      invitado:   nil,
      oferta:     %{},    # %{usuario => id_pokemon}
      confirmado: MapSet.new(),
      timer:      timer
    }

    {:ok, estado}
  end

  @impl true
  def handle_call({:unirse, usuario}, _from, estado) do
    cond do
      estado.invitado != nil ->
        IO.puts("[Error] La sala #{estado.codigo} ya tiene dos participantes.")
        {:reply, :error, estado}

      usuario == estado.creador ->
        IO.puts("[Error] No puedes unirte a tu propia sala de intercambio.")
        {:reply, :error, estado}

      true ->
        # Cancelar el temporizador de creación
        if estado.timer, do: Process.cancel_timer(estado.timer)

        # Iniciar el temporizador de negociación activa
        nuevo_timer = Process.send_after(self(), :timeout_activo, @timeout_activo)

        estado_con_invitado = %{estado | invitado: usuario, timer: nuevo_timer}
        IO.puts("[Sala #{estado.codigo}] #{usuario} se ha unido. Ya pueden intercambiar (Tiempo límite: 120s).")
        {:reply, :ok, estado_con_invitado}
    end
  end

  @impl true
  def handle_call({:ofrecer, usuario, id_pokemon}, _from, estado) do
    entrenador = GestorEntrenadores.get_entrenador(usuario)

    if entrenador && Enum.any?(entrenador.inventario, &(&1.id == id_pokemon)) do
      nueva_oferta         = Map.put(estado.oferta, usuario, id_pokemon)
      estado_con_oferta    = %{estado | oferta: nueva_oferta, confirmado: MapSet.new()}
      IO.puts("[Sala #{estado.codigo}] #{usuario} ofrece el Pokémon ##{id_pokemon}")
      mostrar_estado_sala(estado_con_oferta)
      {:reply, :ok, estado_con_oferta}
    else
      IO.puts("[Error] El Pokémon ##{id_pokemon} no está en tu inventario.")
      {:reply, :error, estado}
    end
  end

  @impl true
  def handle_call({:confirmar, usuario}, _from, estado) do
    confirmados_actualizados = MapSet.put(estado.confirmado, usuario)
    estado_con_confirmacion  = %{estado | confirmado: confirmados_actualizados}

    participantes      = [estado.creador, estado.invitado]
    todos_confirmaron  = Enum.all?(participantes, fn participante -> participante != nil and MapSet.member?(confirmados_actualizados, participante) end)
    ambos_ofrecieron   = Enum.all?(participantes, fn participante -> participante != nil and Map.has_key?(estado.oferta, participante) end)

    if todos_confirmaron and ambos_ofrecieron do
      ejecutar_intercambio(estado_con_confirmacion)
    else
      IO.puts("[Sala #{estado.codigo}] #{usuario} confirmó. Esperando confirmación del otro entrenador...")
      {:reply, :ok, estado_con_confirmacion}
    end
  end

  @impl true
  def handle_call({:cancelar, usuario}, _from, estado) do
    IO.puts("[Sala #{estado.codigo}] #{usuario} canceló el intercambio. Sala cerrada.")
    if estado.timer, do: Process.cancel_timer(estado.timer)
    limpiar_tabla(estado.codigo)
    {:stop, :normal, :ok, estado}
  end

  @impl true
  def handle_call(:get_estado, _from, estado), do: {:reply, estado, estado}

  @impl true
  def terminate(_reason, estado) do
    if Map.has_key?(estado, :timer) and estado.timer, do: Process.cancel_timer(estado.timer)
    limpiar_tabla(estado.codigo)
    :ok
  end

  @impl true
  def handle_info(:timeout_creacion, estado) do
    IO.puts("\n[Sala #{estado.codigo}] Expiró por límite de tiempo (timeout) sin que se uniera ningún entrenador. Sala cerrada.")
    limpiar_tabla(estado.codigo)
    {:stop, :normal, estado}
  end

  @impl true
  def handle_info(:timeout_activo, estado) do
    IO.puts("\n[Sala #{estado.codigo}] Expiró por inactividad durante la negociación (límite de 120s superado). Sala cerrada.")
    limpiar_tabla(estado.codigo)
    {:stop, :normal, estado}
  end

  # ─── Helpers ────────────────────────────────────────────────────────────────

  defp ejecutar_intercambio(estado) do
    [usuario_creador, usuario_invitado] = [estado.creador, estado.invitado]
    id_pokemon_creador  = Map.get(estado.oferta, usuario_creador)
    id_pokemon_invitado = Map.get(estado.oferta, usuario_invitado)

    with {:ok, pokemon_recibido_por_creador}  <- GestorEntrenadores.transferir_pokemon(usuario_invitado, usuario_creador, id_pokemon_invitado),
         {:ok, pokemon_recibido_por_invitado} <- GestorEntrenadores.transferir_pokemon(usuario_creador, usuario_invitado, id_pokemon_creador) do
      IO.puts("""
      [Intercambio completado]
        #{usuario_creador} recibió [##{pokemon_recibido_por_creador.id}] #{String.capitalize(pokemon_recibido_por_creador.especie)}.
        #{usuario_invitado} recibió [##{pokemon_recibido_por_invitado.id}] #{String.capitalize(pokemon_recibido_por_invitado.especie)}.
      """)
    else
      {:error, mensaje} -> IO.puts("[Error en intercambio] #{mensaje}")
    end

    if estado.timer, do: Process.cancel_timer(estado.timer)
    limpiar_tabla(estado.codigo)
    {:stop, :normal, :ok, estado}
  end

  defp mostrar_estado_sala(estado) do
    usuario1 = estado.creador
    usuario2 = estado.invitado || "?"

    oferta_usuario1 = case Map.get(estado.oferta, usuario1) do
      nil -> "sin ofrecer"
      id  -> "##{id}"
    end

    oferta_usuario2 = case Map.get(estado.oferta, usuario2) do
      nil -> "sin ofrecer"
      id  -> "##{id}"
    end

    IO.puts("""
    [Sala #{estado.codigo}]
      #{usuario1} → #{oferta_usuario1}
      #{usuario2} → #{oferta_usuario2}
    """)

    if map_size(estado.oferta) == 2 do
      IO.puts("Ambos han ofrecido. Confirma con: confirmar_intercambio")
    end
  end

  defp generar_codigo do
    numero = :rand.uniform(999)
    "#{@id_prefix}#{String.pad_leading(to_string(numero), 3, "0")}"
  end

  defp asegurar_tabla do
    if :ets.whereis(@tabla_intercambios) == :undefined do
      :ets.new(@tabla_intercambios, [:named_table, :public, :set])
    end
  end

  defp buscar_sala(codigo) do
    if :ets.whereis(@tabla_intercambios) != :undefined do
      case :ets.lookup(@tabla_intercambios, codigo) do
        [{_codigo, pid_sala}] -> pid_sala
        []                    -> nil
      end
    end
  end

  defp sala_del_usuario(usuario) do
    if :ets.whereis(@tabla_intercambios) != :undefined do
      :ets.tab2list(@tabla_intercambios)
      |> Enum.find_value(fn {_codigo, pid_sala} ->
        estado_sala =
          try do
            GenServer.call(pid_sala, :get_estado, 1000)
          catch
            :exit, _ -> nil
          end
        if estado_sala && (estado_sala.creador == usuario or estado_sala.invitado == usuario), do: pid_sala
      end)
    end
  end

  defp limpiar_tabla(codigo) do
    if :ets.whereis(@tabla_intercambios) != :undefined do
      :ets.delete(@tabla_intercambios, codigo)
    end
  end
end
