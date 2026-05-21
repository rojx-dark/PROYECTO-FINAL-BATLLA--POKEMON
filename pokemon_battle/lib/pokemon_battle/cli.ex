defmodule PokemonBattle.CLI do
  @moduledoc """
  Interfaz interactiva de línea de comandos (CLI) para Pokemon Battle.
  Comunicación con el nodo servidor vía RPC.
  Bucle de batalla sincrónico con polling.
  """

  def iniciar do
    IO.puts "\n========================================"
    IO.puts "   🎮 BIENVENIDO A POKÉMON BATTLE 🎮"
    IO.puts "========================================\n"
    conectar_nodo()
  end

  defp conectar_nodo do
    nodo_str = IO.gets("Conectar al nodo servidor (ej. arena@127.0.0.1): ") |> String.trim()

    servidor = if nodo_str != "" do
      nodo = String.to_atom(nodo_str)
      case Node.connect(nodo) do
        true ->
          IO.puts("✅ Conexión exitosa al servidor.")
          nodo
        false ->
          IO.puts("❌ Falló la conexión. Jugando en modo local.")
          Node.self()
        :ignored ->
          IO.puts("✅ Ya estás conectado.")
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
            IO.puts("\n✅ ¡Bienvenido, #{usuario}!")
            menu_usuario(servidor, usuario)
          {:error, msg} ->
            IO.puts("\n❌ Error: " <> msg)
            menu_auth(servidor)
          _ ->
            IO.puts("\n❌ Error de conexión con el servidor.")
            menu_auth(servidor)
        end
      "2" ->
        IO.puts("¡Hasta luego!")
      _ ->
        IO.puts("⚠️ Opción inválida.")
        menu_auth(servidor)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════════
  # MENÚ PRINCIPAL
  # ═══════════════════════════════════════════════════════════════════════════════

  defp menu_usuario(servidor, usuario) do
    IO.puts "\n===================================="
    IO.puts " 🏕️  CAMPAMENTO DE #{String.upcase(usuario)}"
    IO.puts "===================================="
    IO.puts "1. 📊 Mi Perfil"
    IO.puts "2. 🎁 Abrir Sobre de Pokémon"
    IO.puts "3. 🎒 Mi Inventario"
    IO.puts "4. 📋 Crear Equipo"
    IO.puts "5. ⭐ Seleccionar Equipo Activo"
    IO.puts "6. ⚔️  Sala de Batallas"
    IO.puts "7. 🤝 Sala de Intercambios"
    IO.puts "8. 🚪 Cerrar Sesión"
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
        ejecutar(servidor, PokemonBattle.GestorEntrenadores, :inventario, [usuario])
        menu_usuario(servidor, usuario)
      "4" ->
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
      "5" ->
        nombre = IO.gets("Nombre del equipo a usar: ") |> String.trim()
        ejecutar(servidor, PokemonBattle.GestorEntrenadores, :usar_equipo, [usuario, nombre])
        menu_usuario(servidor, usuario)
      "6" ->
        menu_batalla(servidor, usuario)
      "7" ->
        menu_intercambio(servidor, usuario)
      "8" ->
        IO.puts("Cerrando sesión...")
        menu_auth(servidor)
      _ ->
        IO.puts("⚠️ Opción inválida.")
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
    IO.puts "\n--- ⚔️  SALA DE ESPERA ---"
    IO.puts "1. Crear nueva sala"
    IO.puts "2. Unirse a una sala"
    IO.puts "3. Iniciar la batalla"
    IO.puts "4. 🔙 Volver al campamento"

    case IO.gets("Elige: ") |> String.trim() do
      "1" ->
        case ejecutar(servidor, PokemonBattle.GestorSalas, :crear_sala, [usuario]) do
          {:ok, id_sala} ->
            IO.puts("\n✅ Sala #{id_sala} creada. Esperando a que tu rival se una...")
            esperar_inicio_batalla(servidor, usuario)
          _ ->
            menu_batalla_lobby(servidor, usuario)
        end
      "2" ->
        codigo = IO.gets("Código de la sala: ") |> String.trim()
        case ejecutar(servidor, PokemonBattle.GestorSalas, :unirse_sala, [usuario, codigo]) do
          :ok ->
            IO.puts("\n✅ Te has unido a la sala #{codigo}. Esperando a que el anfitrión inicie...")
            esperar_inicio_batalla(servidor, usuario)
          _ ->
            menu_batalla_lobby(servidor, usuario)
        end
      "3" ->
        codigo = IO.gets("Código de la sala: ") |> String.trim()
        case ejecutar(servidor, PokemonBattle.GestorSalas, :iniciar_batalla, [codigo, usuario]) do
          {:ok, _pid} ->
            IO.puts("\n🔥 ¡BATALLA INICIADA!")
            loop_batalla(servidor, usuario, 0)
          _ ->
            menu_batalla_lobby(servidor, usuario)
        end
      "4" ->
        menu_usuario(servidor, usuario)
      _ ->
        IO.puts("⚠️ Opción inválida.")
        menu_batalla_lobby(servidor, usuario)
    end
  end

  # ─── Esperar a que el anfitrión inicie la batalla ───────────────────────────

  defp esperar_inicio_batalla(servidor, usuario) do
    case ejecutar(servidor, PokemonBattle.GestorSalas, :estado_batalla, [usuario]) do
      {:ok, estado} ->
        IO.puts("\n🔥 ¡BATALLA INICIADA! Entrando al combate...")
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
          IO.puts("\n✅ Tu rival ya se unió. Escribe 'iniciar' para empezar la batalla:")
          entrada = IO.gets("") |> String.trim() |> String.downcase()
          if entrada == "iniciar" do
            case ejecutar(servidor, PokemonBattle.GestorSalas, :iniciar_batalla, [id_sala, usuario]) do
              {:ok, _pid} ->
                IO.puts("\n🔥 ¡BATALLA INICIADA!")
                Process.sleep(500)
                loop_batalla(servidor, usuario, 0)
              _ ->
                esperar_inicio_batalla(servidor, usuario)
            end
          else
            esperar_inicio_batalla(servidor, usuario)
          end
        else
          estado_msg = if es_creador?, do: "⏳ Esperando a tu rival...", else: "⏳ Esperando que el anfitrión inicie..."
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
        IO.puts(" 🏁 La batalla ha terminado.")
        IO.puts("════════════════════════════════════")
        menu_usuario(servidor, usuario)
      _ ->
        IO.puts("\n🏁 La batalla ha concluido.")
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
      IO.puts " ⚔️  TURNO #{estado.turno}"
      IO.puts "════════════════════════════════════════════"
      IO.puts " 🔵 Tu Pokémon: #{String.capitalize(mi_pokemon.especie)} | ❤️  #{mi_pokemon.salud}/100 | Equipo vivo: #{mis_vivos}"
      IO.puts " 🔴 Rival (#{rival}): #{String.capitalize(rival_pokemon.especie)} | ❤️  #{rival_pokemon.salud}/100 | Equipo vivo: #{rival_vivos}"
      IO.puts "════════════════════════════════════════════"
    end

    ya_ataque? = if soy_jugador1?, do: estado.accion1 != nil, else: estado.accion2 != nil

    if ya_ataque? do
      # Polling: esperar al rival
      IO.write("⏳ Esperando al rival... (Turno #{estado.turno})\r")
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
      IO.puts("  #{idx_rendirse}. 🏳️  Rendirse")

      entrada = IO.gets("\nElige (1-#{idx_rendirse}): ") |> String.trim()

      case Integer.parse(entrada) do
        {^idx_rendirse, _} ->
          IO.puts("🏳️  Te has rendido...")
          ejecutar(servidor, PokemonBattle.GestorSalas, :enviar_accion, [usuario, :rendirse])
          # La batalla terminará inmediatamente, consultamos resultado
          Process.sleep(500)
          loop_batalla(servidor, usuario, estado.turno)

        {num, _} when num >= 1 and num <= length(movimientos) ->
          mov_elegido = Enum.at(movimientos, num - 1)
          IO.puts("✅ #{String.capitalize(mov_elegido.nombre)} seleccionado.")
          ejecutar(servidor, PokemonBattle.GestorSalas, :enviar_accion, [usuario, {:ataque, mov_elegido.nombre}])
          # Esperar al rival o pasar al siguiente turno
          Process.sleep(500)
          loop_batalla(servidor, usuario, estado.turno)

        _ ->
          IO.puts("⚠️ Opción inválida.")
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

  defp menu_intercambio(servidor, usuario) do
    IO.puts "\n--- 🤝 CENTRO DE INTERCAMBIOS ---"
    IO.puts "1. Crear sala de intercambio"
    IO.puts "2. Unirse a una sala"
    IO.puts "3. Ofrecer un Pokémon"
    IO.puts "4. Confirmar intercambio"
    IO.puts "5. 🔙 Volver al campamento"

    case IO.gets("Elige: ") |> String.trim() do
      "1" ->
        ejecutar(servidor, PokemonBattle.Intercambio, :crear_sala, [usuario])
        menu_intercambio(servidor, usuario)
      "2" ->
        codigo = IO.gets("Código de sala: ") |> String.trim()
        ejecutar(servidor, PokemonBattle.Intercambio, :unirse_sala, [usuario, codigo])
        menu_intercambio(servidor, usuario)
      "3" ->
        id_str = IO.gets("ID del Pokémon a ofrecer: ") |> String.trim()
        case Integer.parse(id_str) do
          {id, _} -> ejecutar(servidor, PokemonBattle.Intercambio, :ofrecer_pokemon, [usuario, id])
          :error -> ejecutar(servidor, PokemonBattle.Intercambio, :ofrecer_pokemon, [usuario, id_str])
        end
        menu_intercambio(servidor, usuario)
      "4" ->
        ejecutar(servidor, PokemonBattle.Intercambio, :confirmar_intercambio, [usuario])
        menu_intercambio(servidor, usuario)
      "5" ->
        menu_usuario(servidor, usuario)
      _ ->
        IO.puts("⚠️ Opción inválida.")
        menu_intercambio(servidor, usuario)
    end
  end
end
