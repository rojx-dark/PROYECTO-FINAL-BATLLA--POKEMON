defmodule PokemonBattle.CLI do
  @moduledoc """
  Interfaz interactiva de línea de comandos (CLI) para Pokemon Battle.
  Comunicación con el nodo servidor vía RPC.
  Bucle de batalla sincrónico con polling.
  """

  def iniciar do
    IO.puts "\n========================================"
    IO.puts "   BIENVENIDO A POKÉMON BATTLE"
    IO.puts "========================================\n"
    conectar_nodo()
  end

  defp conectar_nodo do
    nodo_str = IO.gets("Conectar al nodo servidor (ej. arena@127.0.0.1): ") |> String.trim()

    servidor = if nodo_str != "" do
      nodo = String.to_atom(nodo_str)
      case Node.connect(nodo) do
        true ->
          IO.puts("Conexión exitosa al servidor.")
          nodo
        false ->
          IO.puts("Falló la conexión. Jugando en modo local.")
          Node.self()
        :ignored ->
          IO.puts("Ya estás conectado.")
          nodo
      end
    else
      Node.self()
    end

    menu_auth(servidor)
  end

  defp ejecutar(servidor, modulo, funcion, args \\ []) do
    :rpc.call(servidor, modulo, funcion, args)
  end

  # ═══════════════════════════════════════════════════════════════════════════════
  # AUTENTICACIÓN
  # ═══════════════════════════════════════════════════════════════════════════════

  defp menu_auth(servidor) do
    IO.puts "\n--- AUTENTICACIÓN ---"
    IO.puts "1. Iniciar sesión / Crear cuenta"
    IO.puts "2. Salir del juego"

    case IO.gets("Elige (1-2): ") |> String.trim() do
      "1" ->
        usuario = IO.gets("Tu nombre de usuario: ") |> String.trim()
        clave = IO.gets("Tu contraseña: ") |> String.trim()

        case ejecutar(servidor, PokemonBattle.GestorEntrenadores, :iniciar_sesion, [usuario, clave]) do
          {:ok, _msg} ->
            IO.puts("\n¡Bienvenido, #{usuario}!")
            menu_usuario(servidor, usuario)
          {:error, msg} ->
            IO.puts("\nError: " <> msg)
            menu_auth(servidor)
          _ ->
            IO.puts("\nError de conexión con el servidor.")
            menu_auth(servidor)
        end
      "2" ->
        IO.puts("¡Hasta luego!")
      _ ->
        IO.puts("Opción inválida.")
        menu_auth(servidor)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════════
  # MENÚ PRINCIPAL
  # ═══════════════════════════════════════════════════════════════════════════════

  defp menu_usuario(servidor, usuario) do
    IO.puts "\n===================================="
    IO.puts " CAMPAMENTO DE #{String.upcase(usuario)}"
    IO.puts "===================================="
    IO.puts "1. Mi Perfil"
    IO.puts "2. Abrir Sobre de Pokémon"
    IO.puts "3. Comprar Sobre de Pokémon"
    IO.puts "4. Mi Inventario"
    IO.puts "5. Crear Equipo"
    IO.puts "6. Seleccionar Equipo Activo"
    IO.puts "7. Sala de Batallas"
    IO.puts "8. Sala de Intercambios"
    IO.puts "9. Cerrar Sesión"
    IO.puts "===================================="

    case IO.gets("Elige: ") |> String.trim() do
      "1" ->
        ejecutar(servidor, PokemonBattle.GestorEntrenadores, :perfil, [usuario])
        menu_usuario(servidor, usuario)
      "2" ->
        tipo = IO.gets("Tipo de sobre (basico/raro/legendario): ") |> String.trim()
        ejecutar(servidor, PokemonBattle.SistemaSobres, :abrir_sobre, [usuario, tipo])
        menu_usuario(servidor, usuario)
      "3" ->
        tipo = IO.gets("Tipo de sobre a comprar (basico/raro/legendario): ") |> String.trim()
        ejecutar(servidor, PokemonBattle.SistemaSobres, :comprar_sobre, [usuario, tipo])
        menu_usuario(servidor, usuario)
      "4" ->
        ejecutar(servidor, PokemonBattle.GestorEntrenadores, :inventario, [usuario])
        menu_usuario(servidor, usuario)
      "5" ->
        nombre = IO.gets("Nombre del equipo: ") |> String.trim()
        ids_str = IO.gets("IDs de Pokémon separados por espacio: ") |> String.trim()
        ids = ids_str |> String.split() |> Enum.map(fn id ->
          case Integer.parse(id) do
            {num, _} -> num
            :error -> id
          end
        end)
        ejecutar(servidor, PokemonBattle.GestorEntrenadores, :crear_equipo, [usuario, nombre, ids])
        menu_usuario(servidor, usuario)
      "6" ->
        nombre = IO.gets("Nombre del equipo a usar: ") |> String.trim()
        ejecutar(servidor, PokemonBattle.GestorEntrenadores, :usar_equipo, [usuario, nombre])
        menu_usuario(servidor, usuario)
      "7" ->
        menu_batalla(servidor, usuario)
      "8" ->
        menu_intercambio(servidor, usuario)
      "9" ->
        IO.puts("Cerrando sesión...")
        menu_auth(servidor)
      _ ->
        IO.puts("Opción inválida.")
        menu_usuario(servidor, usuario)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════════
  # SALA DE ESPERA (pre-batalla)
  # ═══════════════════════════════════════════════════════════════════════════════

  defp menu_batalla(servidor, usuario) do
    # Comprobar si ya tenemos una batalla activa
    case ejecutar(servidor, PokemonBattle.GestorSalas, :estado_batalla, [usuario]) do
      {:ok, estado} ->
        loop_batalla(servidor, usuario, estado.turno - 1)
      {:esperando, _} ->
        # Estamos en una sala pero la batalla no ha comenzado
        esperar_inicio_batalla(servidor, usuario)
      _ ->
        menu_batalla_lobby(servidor, usuario)
    end
  end

  defp menu_batalla_lobby(servidor, usuario) do
    IO.puts "\n--- SALA DE ESPERA ---"
    IO.puts "1. Crear nueva sala"
    IO.puts "2. Unirse a una sala"
    IO.puts "3. Iniciar la batalla"
    IO.puts "4. Volver al campamento"

    case IO.gets("Elige: ") |> String.trim() do
      "1" ->
        case ejecutar(servidor, PokemonBattle.GestorSalas, :crear_sala, [usuario]) do
          {:ok, id_sala} ->
            IO.puts("\nSala #{id_sala} creada. Esperando a que tu rival se una...")
            esperar_inicio_batalla(servidor, usuario)
          _ ->
            menu_batalla_lobby(servidor, usuario)
        end
      "2" ->
        codigo = IO.gets("Código de la sala: ") |> String.trim()
        case ejecutar(servidor, PokemonBattle.GestorSalas, :unirse_sala, [usuario, codigo]) do
          :ok ->
            IO.puts("\nTe has unido a la sala #{codigo}. Esperando a que el anfitrión inicie...")
            esperar_inicio_batalla(servidor, usuario)
          _ ->
            menu_batalla_lobby(servidor, usuario)
        end
      "3" ->
        codigo = IO.gets("Código de la sala: ") |> String.trim()
        case ejecutar(servidor, PokemonBattle.GestorSalas, :iniciar_batalla, [codigo, usuario]) do
          {:ok, _pid} ->
            IO.puts("\nBATALLA INICIADA!")
            loop_batalla(servidor, usuario, 0)
          _ ->
            menu_batalla_lobby(servidor, usuario)
        end
      "4" ->
        menu_usuario(servidor, usuario)
      _ ->
        IO.puts("Opción inválida.")
        menu_batalla_lobby(servidor, usuario)
    end
  end

  # ─── Esperar a que el anfitrión inicie la batalla ───────────────────────────

  defp esperar_inicio_batalla(servidor, usuario) do
    case ejecutar(servidor, PokemonBattle.GestorSalas, :estado_batalla, [usuario]) do
      {:ok, estado} ->
        IO.puts("\nBATALLA INICIADA! Entrando al combate...")
        loop_batalla(servidor, usuario, estado.turno - 1)
      {:terminada, _} ->
        IO.puts("\nLa batalla ya terminó.")
        menu_usuario(servidor, usuario)
      {:esperando, _} ->
        # Verificar si este usuario es el creador de la sala (jugador1)
        id_sala = ejecutar(servidor, PokemonBattle.GestorSalas, :sala_de, [usuario])
        sala = ejecutar(servidor, PokemonBattle.GestorSalas, :sala_info, [id_sala])
        es_creador? = sala != nil and sala.jugadores != [] and hd(sala.jugadores) == usuario
        hay_dos? = sala != nil and length(sala.jugadores) >= 2

        if es_creador? and hay_dos? do
          IO.puts("\nTu rival ya se unió. Escribe 'iniciar' para empezar la batalla:")
          entrada = IO.gets("") |> String.trim() |> String.downcase()
          if entrada == "iniciar" do
            case ejecutar(servidor, PokemonBattle.GestorSalas, :iniciar_batalla, [id_sala, usuario]) do
              {:ok, _pid} ->
                IO.puts("\nBATALLA INICIADA!")
                Process.sleep(500)
                loop_batalla(servidor, usuario, 0)
              _ ->
                esperar_inicio_batalla(servidor, usuario)
            end
          else
            esperar_inicio_batalla(servidor, usuario)
          end
        else
          estado_msg = if es_creador?, do: "Esperando a tu rival...", else: "Esperando que el anfitrión inicie..."
          IO.write("#{estado_msg}\r")
          Process.sleep(2000)
          esperar_inicio_batalla(servidor, usuario)
        end
      _ ->
        IO.puts("\nNo estás en ninguna sala.")
        menu_batalla_lobby(servidor, usuario)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════════
  # BUCLE DE BATALLA SINCRÓNICO
  # ═══════════════════════════════════════════════════════════════════════════════

  defp loop_batalla(servidor, usuario, turno_anterior) do
    case ejecutar(servidor, PokemonBattle.GestorSalas, :estado_batalla, [usuario]) do
      {:ok, estado} ->
        if estado.terminada do
          mostrar_resultado_final(estado, usuario)
          menu_usuario(servidor, usuario)
        else
          procesar_turno(servidor, usuario, estado, turno_anterior)
        end
      {:terminada, _} ->
        IO.puts("\n════════════════════════════════════")
        IO.puts(" La batalla ha terminado.")
        IO.puts("════════════════════════════════════")
        menu_usuario(servidor, usuario)
      _ ->
        IO.puts("\nLa batalla ha concluido.")
        menu_usuario(servidor, usuario)
    end
  end

  defp procesar_turno(servidor, usuario, estado, turno_anterior) do
    soy_jugador1? = (estado.jugador1 == usuario)
    rival = if soy_jugador1?, do: estado.jugador2, else: estado.jugador1

    mi_equipo = if soy_jugador1?, do: estado.equipo1, else: estado.equipo2
    rival_equipo = if soy_jugador1?, do: estado.equipo2, else: estado.equipo1
    mi_activo_id = if soy_jugador1?, do: estado.activo1, else: estado.activo2
    rival_activo_id = if soy_jugador1?, do: estado.activo2, else: estado.activo1

    mi_pokemon = Enum.find(mi_equipo, &(&1.id == mi_activo_id))
    rival_pokemon = Enum.find(rival_equipo, &(&1.id == rival_activo_id))

    # Mostrar estado del turno solo si es un turno nuevo
    if estado.turno > turno_anterior do
      mis_vivos = Enum.count(mi_equipo, &(&1.salud > 0))
      rival_vivos = Enum.count(rival_equipo, &(&1.salud > 0))

      IO.puts "\n════════════════════════════════════════════"
      IO.puts " TURNO #{estado.turno}"
      IO.puts "════════════════════════════════════════════"
      IO.puts " Tu Pokémon: #{String.capitalize(mi_pokemon.especie)} | #{mi_pokemon.salud}/100 | Equipo vivo: #{mis_vivos}"
      IO.puts " Rival (#{rival}): #{String.capitalize(rival_pokemon.especie)} | #{rival_pokemon.salud}/100 | Equipo vivo: #{rival_vivos}"
      IO.puts "════════════════════════════════════════════"
    end

    ya_ataque? = if soy_jugador1?, do: estado.accion1 != nil, else: estado.accion2 != nil

    if ya_ataque? do
      # Polling: esperar al rival
      IO.write("Esperando al rival... (Turno #{estado.turno})\r")
      Process.sleep(1500)
      loop_batalla(servidor, usuario, turno_anterior)
    else
      # Mostrar movimientos disponibles
      IO.puts("\n¿Qué movimiento usas?")
      movimientos = mi_pokemon.movimientos
      Enum.with_index(movimientos, 1) |> Enum.each(fn {mov, idx} ->
        IO.puts("  #{idx}. #{String.capitalize(mov.nombre)} (Poder: #{mov.poder_base}, Tipo: #{mov.tipo})")
      end)
      idx_rendirse = length(movimientos) + 1
      IO.puts("  #{idx_rendirse}. Rendirse")

      entrada = IO.gets("\nElige (1-#{idx_rendirse}): ") |> String.trim()

      case Integer.parse(entrada) do
        {^idx_rendirse, _} ->
          IO.puts("Te has rendido...")
          ejecutar(servidor, PokemonBattle.GestorSalas, :enviar_accion, [usuario, :rendirse])
          # La batalla terminará inmediatamente, consultamos resultado
          Process.sleep(500)
          loop_batalla(servidor, usuario, estado.turno)

        {num, _} when num >= 1 and num <= length(movimientos) ->
          mov_elegido = Enum.at(movimientos, num - 1)
          IO.puts("#{String.capitalize(mov_elegido.nombre)} seleccionado.")
          ejecutar(servidor, PokemonBattle.GestorSalas, :enviar_accion, [usuario, {:ataque, mov_elegido.nombre}])
          # Esperar al rival o pasar al siguiente turno
          Process.sleep(500)
          loop_batalla(servidor, usuario, estado.turno)

        _ ->
          IO.puts("Opción inválida.")
          procesar_turno(servidor, usuario, estado, turno_anterior)
      end
    end
  end

  defp mostrar_resultado_final(estado, usuario) do
    IO.puts "\n╔══════════════════════════════════════╗"
    if estado.ganador == usuario do
      IO.puts " 🏆 ¡FELICIDADES, GANASTE! 🏆"
      IO.puts " +100 monedas de recompensa"
    else
      IO.puts " 💀 HAS PERDIDO"
      IO.puts " +30 monedas de consolación"
    end
    IO.puts " Turnos jugados: #{estado.turno}"
    IO.puts "╚══════════════════════════════════════╝"
  end

  # ═══════════════════════════════════════════════════════════════════════════════
  # INTERCAMBIOS
  # ═══════════════════════════════════════════════════════════════════════════════

  # Punto de entrada: si ya estás en una sala activa, entras directo; si no, lobby.
  defp menu_intercambio(servidor, usuario) do
    case ejecutar(servidor, PokemonBattle.Intercambio, :estado_sala, [usuario]) do
      {:ok, estado_sala} ->
        # Ya estamos en una sala activa con dos jugadores
        sala_intercambio_activa(servidor, usuario, estado_sala)

      {:esperando, codigo} ->
        # Sala creada pero sin rival todavía
        IO.puts("\nSala #{codigo} esperando rival...")
        esperar_rival_intercambio(servidor, usuario, codigo)

      _ ->
        # Sin sala: mostrar lobby
        menu_intercambio_lobby(servidor, usuario)
    end
  end

  # ─── Lobby de intercambio ────────────────────────────────────────────────────

  defp menu_intercambio_lobby(servidor, usuario) do
    IO.puts "\n╔══════════════════════════════════════╗"
    IO.puts " 🤝  CENTRO DE INTERCAMBIOS"
    IO.puts "╚══════════════════════════════════════╝"
    IO.puts "1. Crear sala de intercambio"
    IO.puts "2. Unirse a una sala existente"
    IO.puts "3. 🔙 Volver al campamento"

    case IO.gets("\nElige: ") |> String.trim() do
      "1" ->
        case ejecutar(servidor, PokemonBattle.Intercambio, :crear_sala, [usuario]) do
          {:ok, codigo} ->
            IO.puts("\n[Sala #{codigo} creada] Comparte este código con tu rival.")
            esperar_rival_intercambio(servidor, usuario, codigo)
          _ ->
            IO.puts("⚠️  No se pudo crear la sala.")
            menu_intercambio_lobby(servidor, usuario)
        end

      "2" ->
        codigo = IO.gets("Código de sala: ") |> String.trim()
        case ejecutar(servidor, PokemonBattle.Intercambio, :unirse_sala, [usuario, codigo]) do
          :ok ->
            IO.puts("\n✅ Te uniste a la sala #{codigo}.")
            # Consultar el estado actual y entrar a la sala activa
            case ejecutar(servidor, PokemonBattle.Intercambio, :estado_sala, [usuario]) do
              {:ok, estado_sala} -> sala_intercambio_activa(servidor, usuario, estado_sala)
              _                  -> menu_intercambio_lobby(servidor, usuario)
            end
          _ ->
            menu_intercambio_lobby(servidor, usuario)
        end

      "3" ->
        menu_usuario(servidor, usuario)

      _ ->
        IO.puts("⚠️  Opción inválida.")
        menu_intercambio_lobby(servidor, usuario)
    end
  end

  # ─── Esperar a que el rival se una ──────────────────────────────────────────

  defp esperar_rival_intercambio(servidor, usuario, codigo) do
    case ejecutar(servidor, PokemonBattle.Intercambio, :estado_sala, [usuario]) do
      {:ok, estado_sala} ->
        IO.puts("\n✅ ¡#{estado_sala.invitado} se unió a la sala #{codigo}!")
        sala_intercambio_activa(servidor, usuario, estado_sala)

      {:esperando, _} ->
        IO.write("Esperando rival en sala #{codigo}... (60s para expirar)\r")
        Process.sleep(2000)
        esperar_rival_intercambio(servidor, usuario, codigo)

      _ ->
        IO.puts("\n⌛ La sala #{codigo} expiró sin que nadie se uniera.")
        menu_intercambio_lobby(servidor, usuario)
    end
  end

  # ─── Sala activa: ofrecer, confirmar, cancelar ──────────────────────────────

  defp sala_intercambio_activa(servidor, usuario, estado_sala) do
    # Primero verificar si la sala sigue viva
    case ejecutar(servidor, PokemonBattle.Intercambio, :estado_sala, [usuario]) do
      {:completado, mensaje} ->
        IO.puts("\n#{mensaje}")
        menu_usuario(servidor, usuario)

      {:cancelado, mensaje} ->
        IO.puts("\n#{mensaje}")
        menu_usuario(servidor, usuario)

      {:error, _} ->
        IO.puts("\n⚠️  La sala ya no está disponible.")
        menu_usuario(servidor, usuario)

      {:ok, estado_actual} ->
        rival = if estado_actual.creador == usuario, do: estado_actual.invitado, else: estado_actual.creador
        mi_oferta    = Map.get(estado_actual.oferta, usuario)
        rival_oferta = Map.get(estado_actual.oferta, rival)
        yo_confirme  = MapSet.member?(estado_actual.confirmado, usuario)

        IO.puts "\n╔══════════════════════════════════════╗"
        IO.puts " 🤝  SALA DE INTERCAMBIO #{estado_actual.codigo}"
        IO.puts "╚══════════════════════════════════════╝"
        IO.puts " Tu oferta  : #{formatear_oferta(mi_oferta)}"
        IO.puts " Rival (#{rival}): #{formatear_oferta(rival_oferta)}"
        IO.puts " Tu confirmación: #{if yo_confirme, do: "✅ Confirmado", else: "⏳ Pendiente"}"
        IO.puts "────────────────────────────────────────"
        IO.puts "1. Ofrecer un Pokémon"
        IO.puts "2. Confirmar intercambio"
        IO.puts "3. Cancelar y salir"

        case IO.gets("\nElige: ") |> String.trim() do
          "1" ->
            id_str = IO.gets("ID del Pokémon a ofrecer: ") |> String.trim()
            id = case Integer.parse(id_str) do
              {num, _} -> num
              :error   -> id_str
            end
            case ejecutar(servidor, PokemonBattle.Intercambio, :ofrecer_pokemon, [usuario, id]) do
              :ok    -> IO.puts(" Oferta registrada.")
              :error -> IO.puts("  No se pudo registrar la oferta.")
              _      -> :ok
            end
            # Polling breve: dar tiempo al rival a ver la oferta y refrescar estado
            refrescar_sala_intercambio(servidor, usuario)

          "2" ->
            case ejecutar(servidor, PokemonBattle.Intercambio, :confirmar_intercambio, [usuario]) do
              :ok ->
                IO.puts(" Confirmación enviada. Esperando al rival...")
                esperar_confirmacion_rival(servidor, usuario)
              {:completado, _} ->
                IO.puts("\n ¡Intercambio completado!")
                menu_usuario(servidor, usuario)
              _ ->
                IO.puts("  No se pudo confirmar.")
                sala_intercambio_activa(servidor, usuario, estado_actual)
            end

          "3" ->
            ejecutar(servidor, PokemonBattle.Intercambio, :cancelar_intercambio, [usuario])
            IO.puts(" Intercambio cancelado.")
            menu_usuario(servidor, usuario)

          _ ->
            IO.puts("  Opción inválida.")
            sala_intercambio_activa(servidor, usuario, estado_actual)
        end

      _ ->
        menu_usuario(servidor, usuario)
    end
  end

  # ─── Polling tras confirmar: esperar que el rival también confirme ───────────

  defp esperar_confirmacion_rival(servidor, usuario) do
    case ejecutar(servidor, PokemonBattle.Intercambio, :estado_sala, [usuario]) do
      {:completado, mensaje} ->
        IO.puts("\n#{mensaje}")
        menu_usuario(servidor, usuario)

      {:ok, estado_actual} ->
        rival = if estado_actual.creador == usuario, do: estado_actual.invitado, else: estado_actual.creador
        rival_confirmo = MapSet.member?(estado_actual.confirmado, rival)

        if rival_confirmo do
          # Ambos confirmaron — el intercambio debió ejecutarse; recargar
          esperar_confirmacion_rival(servidor, usuario)
        else
          IO.write("Esperando que #{rival} confirme...\r")
          Process.sleep(1500)
          esperar_confirmacion_rival(servidor, usuario)
        end

      {:cancelado, mensaje} ->
        IO.puts("\n#{mensaje}")
        menu_usuario(servidor, usuario)

      _ ->
        IO.puts("\n  La sala cerró inesperadamente.")
        menu_usuario(servidor, usuario)
    end
  end

  # ─── Refrescar estado de sala tras ofrecer ──────────────────────────────────

  defp refrescar_sala_intercambio(servidor, usuario) do
    case ejecutar(servidor, PokemonBattle.Intercambio, :estado_sala, [usuario]) do
      {:ok, estado_sala}      -> sala_intercambio_activa(servidor, usuario, estado_sala)
      {:completado, mensaje}  -> IO.puts("\n#{mensaje}"); menu_usuario(servidor, usuario)
      _                       -> menu_usuario(servidor, usuario)
    end
  end

  defp formatear_oferta(nil), do: "sin ofrecer"
  defp formatear_oferta(id),  do: "Pokémon ##{id}"
end
