defmodule PokemonBattle.Servidor do
  @moduledoc """
  Interfaz CLI y enrutamiento de comandos del sistema PokemonBattle.
  Lee comandos del stdin y los delega al módulo correspondiente.
  """
  use GenServer
  require Logger

  # ─── API pública ────────────────────────────────────────────────────────────

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  # ─── Callbacks GenServer ─────────────────────────────────────────────────────

  @impl true
  def init(:ok) do
    # Lanzar el loop de lectura en un proceso separado para no bloquear el servidor
    spawn_link(fn -> loop(nil) end)
    {:ok, %{}}
  end

  # ─── Loop de comandos ────────────────────────────────────────────────────────

  defp loop(sesion) do
    IO.write("> ")

    case IO.gets("") do
      :eof ->
        Logger.info("EOF recibido, cerrando servidor.")

      {:error, reason} ->
        Logger.error("Error leyendo entrada: #{inspect(reason)}")

      line ->
        line = String.trim(line)
        nueva_sesion = despachar(line, sesion)
        loop(nueva_sesion)
    end
  end

  # ─── Despacho de comandos ────────────────────────────────────────────────────

  defp despachar("", sesion), do: sesion

  defp despachar("iniciar " <> resto, _sesion) do
    case String.split(resto) do
      [usuario, clave] ->
        case PokemonBattle.GestorEntrenadores.iniciar_sesion(usuario, clave) do
          {:ok, msg} ->
            IO.puts(msg)
            usuario

          {:error, msg} ->
            IO.puts("[Error] #{msg}")
            nil
        end

      _ ->
        IO.puts("[Error] Uso: iniciar <usuario> <clave>")
        nil
    end
  end

  defp despachar("salir", sesion) when sesion != nil do
    IO.puts("Hasta luego, #{sesion}!")
    nil
  end

  defp despachar("perfil", sesion), do: con_sesion(sesion, fn u -> PokemonBattle.GestorEntrenadores.perfil(u) end)
  defp despachar("inventario", sesion), do: con_sesion(sesion, fn u -> PokemonBattle.GestorEntrenadores.inventario(u) end)
  defp despachar("clasificacion", _sesion) do
    PokemonBattle.GestorEntrenadores.clasificacion()
    nil
  end

  defp despachar("tienda", _sesion) do
    PokemonBattle.SistemaSobres.mostrar_tienda()
    nil
  end

  defp despachar("comprar_sobre " <> tipo, sesion) do
    con_sesion(sesion, fn u -> PokemonBattle.SistemaSobres.comprar_sobre(u, String.trim(tipo)) end)
  end

  defp despachar("abrir_sobre " <> id_sobre, sesion) do
    con_sesion(sesion, fn u -> PokemonBattle.SistemaSobres.abrir_sobre(u, String.trim(id_sobre)) end)
  end

  defp despachar("listar_equipos", sesion), do: con_sesion(sesion, fn u -> PokemonBattle.GestorEntrenadores.listar_equipos(u) end)

  defp despachar("crear_equipo " <> resto, sesion) do
    con_sesion(sesion, fn u ->
      case String.split(resto, " ", parts: 2) do
        [nombre, ids] ->
          pokemon_ids = ids |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.map(&String.to_integer/1)
          PokemonBattle.GestorEntrenadores.crear_equipo(u, nombre, pokemon_ids)
        _ ->
          IO.puts("[Error] Uso: crear_equipo <nombre> <id1[,id2,id3]>")
      end
    end)
  end

  defp despachar("usar_equipo " <> nombre, sesion) do
    con_sesion(sesion, fn u -> PokemonBattle.GestorEntrenadores.usar_equipo(u, String.trim(nombre)) end)
  end

  defp despachar("agregar_pokemon_equipo " <> resto, sesion) do
    con_sesion(sesion, fn u ->
      case String.split(resto) do
        [nombre_equipo, id_str] -> PokemonBattle.GestorEntrenadores.agregar_pokemon_equipo(u, nombre_equipo, String.to_integer(id_str))
        _ -> IO.puts("[Error] Uso: agregar_pokemon_equipo <nombre_equipo> <id_pokemon>")
      end
    end)
  end

  defp despachar("quitar_pokemon_equipo " <> resto, sesion) do
    con_sesion(sesion, fn u ->
      case String.split(resto) do
        [nombre_equipo, id_str] -> PokemonBattle.GestorEntrenadores.quitar_pokemon_equipo(u, nombre_equipo, String.to_integer(id_str))
        _ -> IO.puts("[Error] Uso: quitar_pokemon_equipo <nombre_equipo> <id_pokemon>")
      end
    end)
  end

  defp despachar("listar_salas", _sesion) do
    PokemonBattle.GestorSalas.listar_salas()
    nil
  end

  defp despachar("crear_sala" <> resto, sesion) do
    con_sesion(sesion, fn u ->
      tiempo = parse_tiempo_turno(resto, 20)
      PokemonBattle.GestorSalas.crear_sala(u, tiempo)
    end)
  end

  defp despachar("unirse_sala " <> id_sala, sesion) do
    con_sesion(sesion, fn u -> PokemonBattle.GestorSalas.unirse_sala(u, String.trim(id_sala)) end)
  end

  defp despachar("iniciar_batalla " <> id_sala, sesion) do
    con_sesion(sesion, fn u -> PokemonBattle.GestorSalas.iniciar_batalla(String.trim(id_sala), u) end)
  end

  defp despachar("ataque " <> movimiento, sesion) do
    con_sesion(sesion, fn u -> PokemonBattle.GestorSalas.enviar_accion(u, {:ataque, String.trim(movimiento)}) end)
  end

  defp despachar("cambiar " <> id_str, sesion) do
    con_sesion(sesion, fn u -> PokemonBattle.GestorSalas.enviar_accion(u, {:cambiar, String.to_integer(String.trim(id_str))}) end)
  end

  defp despachar("rendirse", sesion) do
    con_sesion(sesion, fn u -> PokemonBattle.GestorSalas.enviar_accion(u, :rendirse) end)
  end

  defp despachar("crear_sala_intercambio", sesion) do
    con_sesion(sesion, fn u -> PokemonBattle.Intercambio.crear_sala(u) end)
  end

  defp despachar("unirse_sala_intercambio " <> codigo, sesion) do
    con_sesion(sesion, fn u -> PokemonBattle.Intercambio.unirse_sala(u, String.trim(codigo)) end)
  end

  defp despachar("ofrecer_pokemon " <> id_str, sesion) do
    con_sesion(sesion, fn u -> PokemonBattle.Intercambio.ofrecer_pokemon(u, String.to_integer(String.trim(id_str))) end)
  end

  defp despachar("confirmar_intercambio", sesion) do
    con_sesion(sesion, fn u -> PokemonBattle.Intercambio.confirmar_intercambio(u) end)
  end

  defp despachar("cancelar_intercambio", sesion) do
    con_sesion(sesion, fn u -> PokemonBattle.Intercambio.cancelar_intercambio(u) end)
  end

  defp despachar("ayuda", _sesion) do
    mostrar_ayuda()
    nil
  end

  defp despachar(cmd, sesion) do
    IO.puts("[Error] Comando desconocido: #{cmd}. Escribe 'ayuda' para ver los comandos disponibles.")
    sesion
  end

  # ─── Helpers ────────────────────────────────────────────────────────────────

  defp con_sesion(nil, _fun) do
    IO.puts("[Error] Debes iniciar sesión primero. Usa: iniciar <usuario> <clave>")
    nil
  end

  defp con_sesion(sesion, fun) do
    fun.(sesion)
    sesion
  end

  defp parse_tiempo_turno(resto, default) do
    case Regex.run(~r/tiempo_turno=(\d+)/, resto) do
      [_, n] -> String.to_integer(n)
      _ -> default
    end
  end

  defp mostrar_ayuda do
    IO.puts("""
    ═══════════════════════════════════════════
     Comandos disponibles - Pokémon Battle
    ═══════════════════════════════════════════
    SESIÓN
      iniciar <usuario> <clave>   - Iniciar/registrar sesión
      salir                       - Cerrar sesión

    PERFIL & ECONOMÍA
      perfil                      - Ver monedas, sobres y pokémon
      inventario                  - Ver todos tus Pokémon con detalle
      clasificacion               - Ranking global de entrenadores

    TIENDA & SOBRES
      tienda                      - Ver tipos de sobre y precios
      comprar_sobre <tipo>        - Comprar un sobre (básico/avanzado)
      abrir_sobre <id|ultimo>     - Abrir un sobre del inventario

    EQUIPOS
      listar_equipos              - Ver tus equipos guardados
      crear_equipo <nombre> <ids> - Crear equipo con IDs separados por coma
      usar_equipo <nombre>        - Cargar equipo para la siguiente batalla
      agregar_pokemon_equipo <eq> <id>  - Agregar pokémon a equipo
      quitar_pokemon_equipo <eq> <id>   - Quitar pokémon de equipo

    BATALLAS
      listar_salas                - Ver salas de batalla disponibles
      crear_sala [tiempo_turno=N] - Crear sala (default 20s por turno)
      unirse_sala <id>            - Unirse a una sala existente
      iniciar_batalla <id>        - Iniciar batalla en sala con 2 jugadores
      ataque <movimiento>         - Atacar con un movimiento
      cambiar <id_pokemon>        - Cambiar pokémon activo
      rendirse                    - Rendirse en batalla

    INTERCAMBIO
      crear_sala_intercambio      - Crear sala de intercambio (obtener código)
      unirse_sala_intercambio <codigo> - Unirse a sala de intercambio
      ofrecer_pokemon <id>        - Proponer pokémon para intercambiar
      confirmar_intercambio       - Confirmar el intercambio
      cancelar_intercambio        - Cancelar y cerrar sala de intercambio
    ═══════════════════════════════════════════
    """)
  end
end
