defmodule PokemonBattle.MotorCombate do
  @moduledoc """
  Motor de combate: cálculo de daño, efectividad de tipos, STAB,
  resolución de turnos y visualización del estado en batalla.
  """

  # Tabla de efectividad (tipo_movimiento -> [tipos_defensores_fuertes])
  @efectividad_fuerte %{
    "Fuego"     => ["Planta", "Hielo", "Bicho"],
    "Agua"      => ["Fuego", "Roca", "Tierra"],
    "Planta"    => ["Agua", "Roca", "Tierra"],
    "Electrico" => ["Agua", "Volador"],
    "Roca"      => ["Fuego", "Hielo", "Volador", "Bicho"]
  }

  # ─── API pública ─────────────────────────────────────────────────────────────

  @doc """
  Calcula el daño final de un movimiento del atacante al defensor.
  Retorna un entero (mínimo 1).
  """
  def calcular_dano(movimiento, pokemon_atacante, pokemon_defensor) do
    poder_movimiento = movimiento.poder_base
    ataque_atacante  = pokemon_atacante.ataque
    defensa_defensor = pokemon_defensor.defensa
    efectividad      = calcular_efectividad(movimiento.tipo, pokemon_defensor.tipos)
    stab             = calcular_stab(movimiento.tipo, pokemon_atacante.tipos)
    factor_aleatorio = 0.85 + :rand.uniform() * 0.15  # 0.85..1.00

    dano_base  = trunc((poder_movimiento * (ataque_atacante / defensa_defensor)) / 5 + 2)
    dano_final = trunc(dano_base * efectividad * stab * factor_aleatorio)

    max(1, dano_final)
  end

  @doc """
  Determina qué pokémon actúa primero según mayor velocidad.
  Desempate aleatorio.
  """
  def orden_por_velocidad(pokemon_uno, pokemon_dos) do
    cond do
      pokemon_uno.velocidad > pokemon_dos.velocidad -> {pokemon_uno, pokemon_dos}
      pokemon_dos.velocidad > pokemon_uno.velocidad -> {pokemon_dos, pokemon_uno}
      true -> if :rand.uniform() < 0.5, do: {pokemon_uno, pokemon_dos}, else: {pokemon_dos, pokemon_uno}
    end
  end

  @doc """
  Muestra el estado del turno en consola para un jugador.
  """
  def mostrar_estado_turno(numero_turno, mi_pokemon, mi_equipo, pokemon_rival, equipo_rival) do
    IO.puts("""
    ═══ Turno #{numero_turno} ═══
    Rival: #{String.capitalize(pokemon_rival.especie)} (#{Enum.join(pokemon_rival.tipos, "/")}) | Salud: #{pokemon_rival.salud}/100
    Equipo rival: #{resumen_equipo(equipo_rival)}

    Tu Pokémon: [##{mi_pokemon.id}] #{String.capitalize(mi_pokemon.especie)} (#{Enum.join(mi_pokemon.tipos, "/")}) | Dueño original: #{mi_pokemon.dueño_original} | Salud: #{mi_pokemon.salud}/100 | Vel: #{mi_pokemon.velocidad}
    Tu equipo:  #{resumen_equipo(mi_equipo)}
    Movimientos:
    """)

    mi_pokemon.movimientos
    |> Enum.with_index(1)
    |> Enum.each(fn {movimiento, indice} ->
      IO.puts("  #{indice}. #{String.pad_trailing(movimiento.nombre, 15)} (#{movimiento.tipo}, poder #{movimiento.poder_base})")
    end)

    IO.puts("\nAcción > ")
  end

  # ─── Helpers privados ────────────────────────────────────────────────────────

  defp calcular_efectividad(tipo_movimiento, tipos_defensor) do
    Enum.reduce(tipos_defensor, 1.0, fn tipo_defensor, modificador_acumulado ->
      modificador =
        cond do
          fuerte_contra?(tipo_movimiento, tipo_defensor) -> 2.0
          fuerte_contra?(tipo_defensor, tipo_movimiento) -> 0.5  # inversa = debilidad
          true -> 1.0
        end

      modificador_acumulado * modificador
    end)
  end

  defp fuerte_contra?(tipo_ataque, tipo_defensa) do
    Map.get(@efectividad_fuerte, tipo_ataque, [])
    |> Enum.member?(tipo_defensa)
  end

  defp calcular_stab(tipo_movimiento, tipos_atacante) do
    if tipo_movimiento in tipos_atacante, do: 1.5, else: 1.0
  end

  defp resumen_equipo(equipo) do
    equipo
    |> Enum.map(fn pokemon ->
      estado_pokemon = cond do
        pokemon[:activo]    -> "activo"
        pokemon.salud <= 0  -> "debilitado"
        true                -> "vivo"
      end
      "[##{pokemon.id}] #{String.capitalize(pokemon.especie)} (#{estado_pokemon})"
    end)
    |> Enum.join(" | ")
  end
end
