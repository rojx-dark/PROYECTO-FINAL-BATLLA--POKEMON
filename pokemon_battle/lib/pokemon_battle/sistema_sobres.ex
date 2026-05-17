defmodule PokemonBattle.SistemaSobres do
  @moduledoc """
  Gestión de la tienda, compra y apertura de sobres.
  Aplica las reglas de asignación de movimientos (sección 5 del spec).
  """
  alias PokemonBattle.{Persistencia, GestorEntrenadores}

  # ─── API pública ─────────────────────────────────────────────────────────────

  def mostrar_tienda do
    tienda = Persistencia.cargar_tienda()
    IO.puts("=== Tienda de Sobres ===")

    Enum.each(tienda["sobres"] || [], fn tipo_sobre ->
      IO.puts("""
        Tipo: #{tipo_sobre["tipo"]}
        Precio: #{tipo_sobre["precio"]} monedas
        Probabilidades: Común #{tipo_sobre["prob_comun"]}% | Raro #{tipo_sobre["prob_raro"]}% | Épico #{tipo_sobre["prob_epico"]}%
      """)
    end)
  end

  def comprar_sobre(usuario, tipo) do
    tienda = Persistencia.cargar_tienda()

    config_sobre = Enum.find(tienda["sobres"] || [], fn tipo_sobre -> tipo_sobre["tipo"] == tipo end)

    if config_sobre do
      precio = config_sobre["precio"]

      case GestorEntrenadores.descontar_monedas(usuario, precio) do
        :ok ->
          sobre = %{id: :rand.uniform(999_999), tipo: tipo}
          GestorEntrenadores.agregar_sobre(usuario, sobre)
          IO.puts("[OK] Sobre '#{tipo}' comprado por #{precio} monedas. ID: #{sobre.id}")

        {:error, mensaje} ->
          IO.puts("[Error] #{mensaje}")
      end
    else
      IO.puts("[Error] Tipo de sobre desconocido: #{tipo}. Usa 'tienda' para ver opciones.")
    end
  end

  def abrir_sobre(usuario, id_str) do
    case GestorEntrenadores.consumir_sobre(usuario, id_str) do
      {:ok, sobre} ->
        pokemon_obtenidos = generar_pokemon_sobre(sobre.tipo, usuario)

        IO.puts("¡Sobre abierto! Obtuviste:\n")

        Enum.with_index(pokemon_obtenidos, 1)
        |> Enum.each(fn {pokemon, indice} ->
          tipos = Enum.join(pokemon.tipos, "/")
          movimientos_str = Enum.map_join(pokemon.movimientos, ", ", fn movimiento -> "#{movimiento.nombre} (#{movimiento.poder_base})" end)
          IO.puts("""
            #{indice}. [##{pokemon.id}] #{String.capitalize(pokemon.especie)} (#{tipos}) [#{pokemon.rareza}] - Dueño original: #{pokemon.dueño_original}
               Movimientos: #{movimientos_str}
          """)
          GestorEntrenadores.agregar_pokemon(usuario, pokemon)
        end)

      {:error, mensaje} ->
        IO.puts("[Error] #{mensaje}")
    end
  end

  # ─── Generación de Pokémon de un sobre ───────────────────────────────────────

  defp generar_pokemon_sobre(tipo_sobre, dueño) do
    tienda        = Persistencia.cargar_tienda()
    especies      = Persistencia.cargar_especies()
    movimientos_db = Persistencia.cargar_movimientos()

    config_sobre = Enum.find(tienda["sobres"] || [], fn sobre -> sobre["tipo"] == tipo_sobre end) || %{}

    for _ <- 1..3 do
      especie     = Enum.random(especies)
      rareza      = sortear_rareza(config_sobre)
      factor      = sortear_factor(rareza)
      tipos_especie = especie["tipos"] || []
      movimientos = asignar_movimientos(tipos_especie, movimientos_db)

      %{
        id:             :rand.uniform(999_999),
        especie:        especie["nombre"],
        dueño_original: dueño,
        rareza:         rareza,
        tipos:          tipos_especie,
        ataque:         round((especie["ataque_base"]    || 50) * (1 + factor / 100)),
        defensa:        round((especie["defensa_base"]   || 50) * (1 + factor / 100)),
        velocidad:      round((especie["velocidad_base"] || 50) * (1 + factor / 100)),
        movimientos:    movimientos
      }
    end
  end

  defp sortear_rareza(config_sobre) do
    numero_aleatorio = :rand.uniform(100)
    prob_comun = config_sobre["prob_comun"] || 70
    prob_raro  = config_sobre["prob_raro"]  || 25

    cond do
      numero_aleatorio <= prob_comun                  -> "comun"
      numero_aleatorio <= prob_comun + prob_raro      -> "raro"
      true                                            -> "epico"
    end
  end

  defp sortear_factor("comun"),  do: Enum.random(2..8)
  defp sortear_factor("raro"),   do: Enum.random(10..20)
  defp sortear_factor("epico"),  do: Enum.random(25..40)
  defp sortear_factor(_),        do: 2

  # ─── Asignación de movimientos (reglas sección 5) ────────────────────────────

  defp asignar_movimientos(tipos_especie, movimientos_db) do
    # Pool de movimientos del tipo de la especie (regla 1)
    movimientos_del_tipo = tipos_especie
    |> Enum.flat_map(fn tipo -> movimientos_db[tipo] || [] end)
    |> Enum.uniq_by(& &1["nombre"])

    # Pool de todos los movimientos disponibles
    movimientos_todos = movimientos_db |> Map.values() |> List.flatten() |> Enum.uniq_by(& &1["nombre"])

    # Elegir al menos 2 del tipo propio (regla 1)
    {movimientos_elegidos, _} = elegir_sin_repetir(movimientos_del_tipo, 2, [])

    # Elegir el resto del pool global (regla 2), sin repetir (regla 3)
    movimientos_restantes = Enum.reject(movimientos_todos, fn movimiento ->
      Enum.any?(movimientos_elegidos, fn elegido -> elegido["nombre"] == movimiento["nombre"] end)
    end)

    {movimientos_complementarios, _} = elegir_sin_repetir(movimientos_restantes, 4 - length(movimientos_elegidos), movimientos_elegidos)

    movimientos_finales = movimientos_elegidos ++ movimientos_complementarios
    Enum.map(movimientos_finales, fn movimiento ->
      %{nombre: movimiento["nombre"], tipo: movimiento["tipo"], poder_base: movimiento["poder_base"]}
    end)
  end

  defp elegir_sin_repetir(pool, cantidad, ya_elegidos) do
    disponibles = Enum.reject(pool, fn movimiento ->
      Enum.any?(ya_elegidos, fn elegido -> elegido["nombre"] == movimiento["nombre"] end)
    end)

    seleccionados =
      disponibles
      |> Enum.shuffle()
      |> Enum.take(cantidad)

    {seleccionados, ya_elegidos ++ seleccionados}
  end
end
