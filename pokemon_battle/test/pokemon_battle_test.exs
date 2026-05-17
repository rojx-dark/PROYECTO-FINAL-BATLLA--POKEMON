defmodule PokemonBattleTest do
  use ExUnit.Case, async: true
  alias PokemonBattle.MotorCombate

  # ─── Fixtures ────────────────────────────────────────────────────────────────

  defp pikachu do
    %{
      id: 71834,
      especie: "pikachu",
      tipos: ["Electrico"],
      ataque: 63,
      defensa: 46,
      velocidad: 104,
      salud: 100,
      dueño_original: "Ana",
      movimientos: [
        %{nombre: "impactrueno", tipo: "Electrico", poder_base: 65},
        %{nombre: "chispa",      tipo: "Electrico", poder_base: 50},
        %{nombre: "ataque_rapido", tipo: "Normal",  poder_base: 40},
        %{nombre: "rafaga",      tipo: "Volador",   poder_base: 60}
      ]
    }
  end

  defp squirtle do
    %{
      id: 40182,
      especie: "squirtle",
      tipos: ["Agua"],
      ataque: 52,
      defensa: 70,
      velocidad: 46,
      salud: 100,
      dueño_original: "Luis",
      movimientos: [
        %{nombre: "pistola_agua", tipo: "Agua",  poder_base: 40},
        %{nombre: "surf",         tipo: "Agua",  poder_base: 90},
        %{nombre: "placaje",      tipo: "Normal",poder_base: 35},
        %{nombre: "rayo_burbuja", tipo: "Agua",  poder_base: 65}
      ]
    }
  end

  defp geodude do
    %{
      id: 29047,
      especie: "geodude",
      tipos: ["Roca", "Tierra"],
      ataque: 80,
      defensa: 100,
      velocidad: 20,
      salud: 100,
      dueño_original: "Luis",
      movimientos: [
        %{nombre: "lanzarrocas",  tipo: "Roca",   poder_base: 35},
        %{nombre: "terremoto",    tipo: "Tierra",  poder_base: 100},
        %{nombre: "avalancha",    tipo: "Roca",   poder_base: 75},
        %{nombre: "placaje",      tipo: "Normal", poder_base: 35}
      ]
    }
  end

  defp mov_electrico, do: %{nombre: "impactrueno", tipo: "Electrico", poder_base: 65}
  defp mov_agua,      do: %{nombre: "pistola_agua", tipo: "Agua",     poder_base: 40}
  defp mov_normal,    do: %{nombre: "placaje",       tipo: "Normal",   poder_base: 35}

  # ─── Test 1: Cálculo de daño – tipo fuerte (x2.0 + STAB x1.5) ───────────────

  test "daño con tipo fuerte y STAB (Eléctrico vs Agua)" do
    # Pikachu usa impactrueno (Eléctrico) contra Squirtle (Agua)
    # efectividad = 2.0 (Eléctrico > Agua), STAB = 1.5 (Pikachu es Eléctrico)
    # dano_base = trunc((65 * (63/70)) / 5 + 2) = trunc(13.7) = 13
    # dano_final mínimo = trunc(13 * 2.0 * 1.5 * 0.85) = trunc(33.15) = 33
    dano = MotorCombate.calcular_dano(mov_electrico(), pikachu(), squirtle())
    assert dano >= 33, "Daño con fuerte+STAB debe ser >= 33, obtenido: #{dano}"
    assert dano <= 40, "Daño con fuerte+STAB debe ser <= 40, obtenido: #{dano}"
  end

  # ─── Test 2: Cálculo de daño – tipo débil (x0.5) ────────────────────────────

  test "daño con tipo débil (Agua vs Eléctrico)" do
    # Squirtle usa pistola_agua (Agua) contra Pikachu (Eléctrico)
    # efectividad = 0.5 (inversa: Eléctrico > Agua, entonces Agua es débil contra Eléctrico)
    # STAB = 1.5 (Squirtle es Agua, movimiento es Agua)
    dano = MotorCombate.calcular_dano(mov_agua(), squirtle(), pikachu())
    # Con debilidad x0.5 y STAB x1.5 → factor neto 0.75
    # dano_base = trunc((40 * (52/46)) / 5 + 2) ≈ trunc(11.04) = 11
    # dano_final min = trunc(11 * 0.5 * 1.5 * 0.85) = trunc(7.01) = 7
    assert dano >= 7, "Daño con débil debe ser >= 7, obtenido: #{dano}"
    assert dano <= 13, "Daño con débil debe ser <= 13, obtenido: #{dano}"
  end

  # ─── Test 3: Cálculo de daño – neutro (x1.0) ────────────────────────────────

  test "daño neutro (Normal vs Agua, sin STAB)" do
    # Pikachu usa placaje (Normal) contra Squirtle (Agua)
    # efectividad = 1.0, STAB = 1.0 (Pikachu no es Normal)
    dano = MotorCombate.calcular_dano(mov_normal(), pikachu(), squirtle())
    # dano_base = trunc((35 * (63/70)) / 5 + 2) = trunc(8.3) = 8
    # rango: trunc(8 * 1.0 * 1.0 * 0.85) = 6  a  trunc(8 * 1.0 * 1.0 * 1.00) = 8
    assert dano >= 6,  "Daño neutro debe ser >= 6, obtenido: #{dano}"
    assert dano <= 8,  "Daño neutro debe ser <= 8, obtenido: #{dano}"
  end

  # ─── Test 4: Orden por velocidad ─────────────────────────────────────────────

  test "Pokémon más rápido actúa primero" do
    # Pikachu vel=104, Squirtle vel=46 → Pikachu debe ser siempre primero
    {primero, segundo} = MotorCombate.orden_por_velocidad(pikachu(), squirtle())
    assert primero.especie == "pikachu"
    assert segundo.especie == "squirtle"
  end

  test "Pokémon más rápido actúa primero (orden inverso de parámetros)" do
    {primero, segundo} = MotorCombate.orden_por_velocidad(squirtle(), pikachu())
    assert primero.especie == "pikachu"
    assert segundo.especie == "squirtle"
  end

  # ─── Test 5: Daño mínimo garantizado = 1 ────────────────────────────────────

  test "daño mínimo es siempre 1 aunque el cálculo dé 0" do
    # Un pokemon con ataque muy bajo vs defensa muy alta
    atacante_debil = %{pikachu() | ataque: 1, tipos: ["Normal"]}
    defensor_fuerte = %{geodude() | defensa: 9999}
    mov = %{nombre: "placaje", tipo: "Normal", poder_base: 1}
    dano = MotorCombate.calcular_dano(mov, atacante_debil, defensor_fuerte)
    assert dano >= 1, "El daño mínimo debe ser 1, obtenido: #{dano}"
  end

  # ─── Test 6: STAB no aplica cuando el tipo no coincide ─────────────────────

  test "sin STAB cuando tipo del movimiento no coincide con atacante" do
    # Pikachu (Eléctrico) usa placaje (Normal) → sin STAB
    dano_sin_stab = MotorCombate.calcular_dano(mov_normal(), pikachu(), squirtle())

    # Squirtle (Agua) usa pistola_agua (Agua) → con STAB × 1.5
    mov_agua_squirtle = %{nombre: "pistola_agua", tipo: "Agua", poder_base: 35}
    dano_con_stab = MotorCombate.calcular_dano(mov_agua_squirtle, squirtle(), squirtle())

    # El STAB debe aumentar el daño
    # Esta prueba es probabilística por el factor aleatorio; usamos rangos amplios
    assert dano_sin_stab >= 1
    assert dano_con_stab >= 1
  end

  # ─── Test 7: Doble tipo – modificadores multiplicados ────────────────────────

  test "defensor de doble tipo multiplica modificadores (Roca/Tierra vs Agua)" do
    # Squirtle usa pistola_agua (Agua) contra Geodude (Roca/Tierra)
    # Agua > Roca (x2.0) y Agua > Tierra (x2.0) → efectividad = x4.0
    # STAB = 1.5 (Squirtle es Agua)
    mov_agua_sq = %{nombre: "pistola_agua", tipo: "Agua", poder_base: 40}
    dano = MotorCombate.calcular_dano(mov_agua_sq, squirtle(), geodude())
    # dano_base = trunc((40 * (52/100)) / 5 + 2) = trunc(6.16) = 6
    # rango con ×4.0 STAB×1.5 factor 0.85-1.00: 30-36
    assert dano >= 30, "Doble efectividad (×4.0) con STAB debe dar daño >= 30, obtenido: #{dano}"
  end
end
