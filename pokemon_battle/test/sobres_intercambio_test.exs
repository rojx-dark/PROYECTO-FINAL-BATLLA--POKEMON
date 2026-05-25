// test/sobres_intercambio_test.exs

ExUnit.start()

defmodule PokemonBattle.SobresIntercambioTest do
  use ExUnit.Case, async: false

  alias PokemonBattle.{SistemaSobres, GestorEntrenadores, Intercambio, SupervisorBatallas}

  setup do
    # Ensure the application and its supervisors are started
    {:ok, _} = Application.ensure_all_started(:pokemon_battle)
    # Use a fresh user for each test
    usuario = "test_user_#{:rand.uniform(1000)}"
    # Register the user (creates a starter sobre)
    :ok = GestorEntrenadores.iniciar_sesion(usuario, "clave")
    # Give the user some money to buy sobres
    :ok = GestorEntrenadores.descontar_monedas(usuario, -500) # add 500 coins
    %{usuario: usuario}
  end

  test "comprar un sobre básico reduce monedas y agrega el sobre al inventario", %{usuario: u} do
    # User has 500 coins from setup
    {:ok, _msg} = SistemaSobres.comprar_sobre(u, "basico")
    # Verify the user now has at least one sobre in its list
    trainer = GestorEntrenadores.get_entrenador(u)
    assert length(trainer.sobres) >= 2 # one starter + purchased
    # Verify that the balance decreased by the price (100)
    assert trainer.monedas_actuales == 400
  end

  test "abrir un sobre existente devuelve Pokémon y lo agrega al inventario", %{usuario: u} do
    # Comprar un sobre para abrir
    {:ok, _} = SistemaSobres.comprar_sobre(u, "avanzado")
    # Obtener ID del último sobre
    trainer = GestorEntrenadores.get_entrenador(u)
    ultimo_id = List.last(trainer.sobres).id
    {:ok, sobre} = GestorEntrenadores.consumir_sobre(u, Integer.to_string(ultimo_id))
    # Abrir el sobre y capturar salida
    capture = ExUnit.CaptureIO.capture_io(fn ->
      SistemaSobres.abrir_sobre(u, Integer.to_string(ultimo_id))
    end)
    # Debe contener la frase de éxito
    assert capture =~ "¡Sobre abierto!"
    # Después de abrir, el inventario debe contener al menos 3 nuevos Pokémon
    trainer2 = GestorEntrenadores.get_entrenador(u)
    assert length(trainer2.inventario) >= 3
  end

  test "flujo completo de intercambio entre dos usuarios", _context do
    # Crear y registrar dos usuarios
    u1 = "alice_#{:rand.uniform(1000)}"
    u2 = "bob_#{:rand.uniform(1000)}"
    :ok = GestorEntrenadores.iniciar_sesion(u1, "pwd")
    :ok = GestorEntrenadores.iniciar_sesion(u2, "pwd")
    # Darles un Pokémon para intercambiar (usar el sobre básico que ya tienen)
    trainer1 = GestorEntrenadores.get_entrenador(u1)
    trainer2 = GestorEntrenadores.get_entrenador(u2)
    # Cada uno tomará el primer Pokémon de su inventario (si no tiene, comprar un sobre)
    if length(trainer1.inventario) == 0 do
      {:ok, _} = SistemaSobres.comprar_sobre(u1, "basico")
      {:ok, _} = SistemaSobres.abrir_sobre(u1, "ultimo")
    end
    if length(trainer2.inventario) == 0 do
      {:ok, _} = SistemaSobres.comprar_sobre(u2, "basico")
      {:ok, _} = SistemaSobres.abrir_sobre(u2, "ultimo")
    end
    # Recuperar los IDs de los Pokémon a ofrecer
    p1_id = (GestorEntrenadores.get_entrenador(u1).inventario |> hd).id
    p2_id = (GestorEntrenadores.get_entrenador(u2).inventario |> hd).id
    # Crear sala de intercambio por el primer usuario
    {:ok, codigo} = Intercambio.crear_sala(u1)
    # El segundo usuario se une
    :ok = Intercambio.unirse_sala(u2, codigo)
    # Cada uno ofrece su Pokémon
    :ok = Intercambio.ofrecer_pokemon(u1, p1_id)
    :ok = Intercambio.ofrecer_pokemon(u2, p2_id)
    # Confirmar intercambio por ambos usuarios
    :ok = Intercambio.confirmar_intercambio(u1)
    :ok = Intercambio.confirmar_intercambio(u2)
    # Verificar que los Pokémon fueron transferidos
    inv1 = GestorEntrenadores.get_entrenador(u1).inventario
    inv2 = GestorEntrenadores.get_entrenador(u2).inventario
    assert Enum.any?(inv1, fn p -> p.id == p2_id end)
    assert Enum.any?(inv2, fn p -> p.id == p1_id end)
  end
end
