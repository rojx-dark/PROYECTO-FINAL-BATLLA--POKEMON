defmodule PokemonBattle.GestorEntrenadores do
  @moduledoc """
  GenServer responsable de la sesión, perfil, inventario, monedas y equipos de entrenadores.
  Mantiene el estado en memoria y lo persiste en data/trainers.json.
  """
  use GenServer
  alias PokemonBattle.Persistencia

  # ─── Estructuras internas ────────────────────────────────────────────────────

  @tipo_sobre_inicial "basico"

  # ─── API pública ─────────────────────────────────────────────────────────────

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def iniciar_sesion(usuario, clave),
    do: GenServer.call(__MODULE__, {:iniciar_sesion, usuario, clave})

  def perfil(usuario),
    do: GenServer.call(__MODULE__, {:perfil, usuario})

  def inventario(usuario),
    do: GenServer.call(__MODULE__, {:inventario, usuario})

  def clasificacion,
    do: GenServer.call(__MODULE__, :clasificacion)

  def listar_equipos(usuario),
    do: GenServer.call(__MODULE__, {:listar_equipos, usuario})

  def crear_equipo(usuario, nombre, ids),
    do: GenServer.call(__MODULE__, {:crear_equipo, usuario, nombre, ids})

  def usar_equipo(usuario, nombre),
    do: GenServer.call(__MODULE__, {:usar_equipo, usuario, nombre})

  def agregar_pokemon_equipo(usuario, nombre_equipo, id),
    do: GenServer.call(__MODULE__, {:agregar_pokemon_equipo, usuario, nombre_equipo, id})

  def quitar_pokemon_equipo(usuario, nombre_equipo, id),
    do: GenServer.call(__MODULE__, {:quitar_pokemon_equipo, usuario, nombre_equipo, id})

  def agregar_pokemon(usuario, pokemon),
    do: GenServer.cast(__MODULE__, {:agregar_pokemon, usuario, pokemon})

  def descontar_monedas(usuario, cantidad),
    do: GenServer.call(__MODULE__, {:descontar_monedas, usuario, cantidad})

  def agregar_sobre(usuario, sobre),
    do: GenServer.cast(__MODULE__, {:agregar_sobre, usuario, sobre})

  def consumir_sobre(usuario, id_sobre),
    do: GenServer.call(__MODULE__, {:consumir_sobre, usuario, id_sobre})

  def recompensar_batalla(ganador, perdedor),
    do: GenServer.cast(__MODULE__, {:recompensar_batalla, ganador, perdedor})

  def get_entrenador(usuario),
    do: GenServer.call(__MODULE__, {:get_entrenador, usuario})

  def transferir_pokemon(de, hacia, id_pokemon),
    do: GenServer.call(__MODULE__, {:transferir_pokemon, de, hacia, id_pokemon})

  def get_equipo_activo(usuario),
    do: GenServer.call(__MODULE__, {:get_equipo_activo, usuario})

  # ─── Callbacks GenServer ─────────────────────────────────────────────────────

  @impl true
  def init(:ok) do
    entrenadores = Persistencia.cargar_entrenadores()
    # Convertir lista a mapa keyed por nombre de usuario
    estado = Enum.into(entrenadores, %{}, fn entrenador_json -> {entrenador_json["usuario"], atomizar(entrenador_json)} end)
    {:ok, estado}
  end

  @impl true
  def handle_call({:iniciar_sesion, usuario, clave}, _from, estado) do
    case Map.get(estado, usuario) do
      nil ->
        # Registro nuevo
        sobre_inicial = generar_sobre(@tipo_sobre_inicial)
        nuevo_entrenador = %{
          usuario: usuario,
          clave: clave,
          victorias: 0,
          monedas_actuales: 0,
          monedas_acumuladas: 0,
          inventario: [],
          sobres: [sobre_inicial],
          equipos: %{},
          equipo_activo: nil
        }
        nuevo_estado = Map.put(estado, usuario, nuevo_entrenador)
        persistir(nuevo_estado)
        {:reply, {:ok, "¡Bienvenido, #{usuario}! Cuenta creada. Recibes 1 sobre básico gratis."}, nuevo_estado}

      %{clave: ^clave} ->
        {:reply, {:ok, "¡Bienvenido de nuevo, #{usuario}!"}, estado}

      _ ->
        {:reply, {:error, "Contraseña incorrecta."}, estado}
    end
  end

  @impl true
  def handle_call({:perfil, usuario}, _from, estado) do
    case Map.get(estado, usuario) do
      nil ->
        {:reply, :ok, estado}

      entrenador ->
        IO.puts("""
        === Perfil de #{entrenador.usuario} ===
        Monedas: #{entrenador.monedas_actuales}
        Sobres pendientes: #{length(entrenador.sobres)}
        Pokémon en inventario: #{length(entrenador.inventario)}
        """)
        {:reply, :ok, estado}
    end
  end

  @impl true
  def handle_call({:inventario, usuario}, _from, estado) do
    case Map.get(estado, usuario) do
      nil ->
        {:reply, :ok, estado}

      entrenador ->
        total = length(entrenador.inventario)
        IO.puts("=== Inventario de #{usuario} (#{total} Pokémon) ===")

        entrenador.inventario
        |> Enum.with_index(1)
        |> Enum.each(fn {pokemon, indice} ->
          tipos = Enum.join(pokemon.tipos, "/")
          movimientos_str = Enum.map_join(pokemon.movimientos, ", ", fn movimiento -> "#{movimiento.nombre}(#{movimiento.poder_base})" end)
          IO.puts("""
            #{indice}. [##{pokemon.id}] #{String.capitalize(pokemon.especie)} (#{tipos}) [#{pokemon.rareza}]
               Ataque: #{pokemon.ataque} | Defensa: #{pokemon.defensa} | Velocidad: #{pokemon.velocidad} | Salud máx: 100
               Dueño original: #{pokemon.dueño_original}
               Movimientos: #{movimientos_str}
          """)
        end)
        {:reply, :ok, estado}
    end
  end

  @impl true
  def handle_call(:clasificacion, _from, estado) do
    ranking =
      estado
      |> Map.values()
      |> Enum.sort_by(fn entrenador -> {-entrenador.victorias, -entrenador.monedas_acumuladas} end)

    IO.puts("""
    === Clasificación Global ===
    #    Entrenador   Victorias   Monedas acumuladas
    """)

    ranking
    |> Enum.with_index(1)
    |> Enum.each(fn {entrenador, posicion} ->
      IO.puts("#{posicion}    #{entrenador.usuario}    #{entrenador.victorias}    #{entrenador.monedas_acumuladas}")
    end)

    {:reply, :ok, estado}
  end

  @impl true
  def handle_call({:listar_equipos, usuario}, _from, estado) do
    case Map.get(estado, usuario) do
      nil ->
        {:reply, :ok, estado}

      entrenador ->
        IO.puts("Equipos guardados:")

        Enum.each(entrenador.equipos, fn {nombre_equipo, ids_pokemon} ->
          pokemon_str = ids_pokemon |> Enum.map(fn id -> "[##{id}]" end) |> Enum.join(", ")
          IO.puts("  #{nombre_equipo}  [#{length(ids_pokemon)}/3]: #{pokemon_str}")
        end)

        {:reply, :ok, estado}
    end
  end

  @impl true
  def handle_call({:crear_equipo, usuario, nombre, ids}, _from, estado) do
    case Map.get(estado, usuario) do
      nil ->
        {:reply, :ok, estado}

      entrenador ->
        cond do
          Map.has_key?(entrenador.equipos, nombre) ->
            IO.puts("[Error] Ya existe un equipo con el nombre '#{nombre}'.")
            {:reply, :error, estado}

          length(ids) < 1 or length(ids) > 3 ->
            IO.puts("[Error] Un equipo debe tener entre 1 y 3 Pokémon.")
            {:reply, :error, estado}

          not todos_en_inventario?(entrenador.inventario, ids) ->
            IO.puts("[Error] Algunos IDs no están en tu inventario.")
            {:reply, :error, estado}

          true ->
            nuevos_equipos = Map.put(entrenador.equipos, nombre, ids)
            entrenador_actualizado = %{entrenador | equipos: nuevos_equipos}
            nuevo_estado = Map.put(estado, usuario, entrenador_actualizado)
            persistir(nuevo_estado)
            IO.puts("[OK] Equipo '#{nombre}' creado con #{length(ids)} Pokémon.")
            {:reply, :ok, nuevo_estado}
        end
    end
  end

  @impl true
  def handle_call({:usar_equipo, usuario, nombre}, _from, estado) do
    case Map.get(estado, usuario) do
      nil ->
        {:reply, :ok, estado}

      entrenador ->
        case Map.get(entrenador.equipos, nombre) do
          nil ->
            IO.puts("[Error] No existe el equipo '#{nombre}'.")
            {:reply, :error, estado}

          ids_pokemon ->
            faltantes = Enum.reject(ids_pokemon, fn id -> Enum.any?(entrenador.inventario, &(&1.id == id)) end)

            if faltantes == [] do
              entrenador_actualizado = %{entrenador | equipo_activo: nombre}
              nuevo_estado = Map.put(estado, usuario, entrenador_actualizado)
              IO.puts("[OK] Equipo '#{nombre}' cargado para la batalla.")
              {:reply, :ok, nuevo_estado}
            else
              IO.puts("[Error] Pokémon faltantes en inventario: #{inspect(faltantes)}")
              {:reply, :error, estado}
            end
        end
    end
  end

  @impl true
  def handle_call({:agregar_pokemon_equipo, usuario, nombre_equipo, id}, _from, estado) do
    case Map.get(estado, usuario) do
      nil ->
        {:reply, :ok, estado}

      entrenador ->
        case Map.get(entrenador.equipos, nombre_equipo) do
          nil ->
            IO.puts("[Error] No existe el equipo '#{nombre_equipo}'.")
            {:reply, :error, estado}

          ids_pokemon when length(ids_pokemon) >= 3 ->
            IO.puts("[Error] El equipo ya tiene 3 Pokémon (máximo).")
            {:reply, :error, estado}

          ids_pokemon ->
            if Enum.any?(entrenador.inventario, &(&1.id == id)) do
              nuevos_ids = ids_pokemon ++ [id]
              nuevo_estado = Map.put(estado, usuario, %{entrenador | equipos: Map.put(entrenador.equipos, nombre_equipo, nuevos_ids)})
              persistir(nuevo_estado)
              IO.puts("[OK] Pokémon ##{id} agregado al equipo '#{nombre_equipo}'.")
              {:reply, :ok, nuevo_estado}
            else
              IO.puts("[Error] El Pokémon ##{id} no está en tu inventario.")
              {:reply, :error, estado}
            end
        end
    end
  end

  @impl true
  def handle_call({:quitar_pokemon_equipo, usuario, nombre_equipo, id}, _from, estado) do
    case Map.get(estado, usuario) do
      nil ->
        {:reply, :ok, estado}

      entrenador ->
        case Map.get(entrenador.equipos, nombre_equipo) do
          nil ->
            IO.puts("[Error] No existe el equipo '#{nombre_equipo}'.")
            {:reply, :error, estado}

          ids_pokemon when length(ids_pokemon) <= 1 ->
            IO.puts("[Error] No puedes quitar el único Pokémon del equipo.")
            {:reply, :error, estado}

          ids_pokemon ->
            nuevos_ids = Enum.reject(ids_pokemon, &(&1 == id))
            nuevo_estado = Map.put(estado, usuario, %{entrenador | equipos: Map.put(entrenador.equipos, nombre_equipo, nuevos_ids)})
            persistir(nuevo_estado)
            IO.puts("[OK] Pokémon ##{id} quitado del equipo '#{nombre_equipo}'.")
            {:reply, :ok, nuevo_estado}
        end
    end
  end

  @impl true
  def handle_call({:descontar_monedas, usuario, cantidad}, _from, estado) do
    case Map.get(estado, usuario) do
      %{monedas_actuales: monedas_actuales} = entrenador when monedas_actuales >= cantidad ->
        entrenador_actualizado = %{entrenador | monedas_actuales: monedas_actuales - cantidad}
        nuevo_estado = Map.put(estado, usuario, entrenador_actualizado)
        persistir(nuevo_estado)
        {:reply, :ok, nuevo_estado}

      _ ->
        {:reply, {:error, "Monedas insuficientes."}, estado}
    end
  end

  @impl true
  def handle_call({:consumir_sobre, usuario, id_str}, _from, estado) do
    case Map.get(estado, usuario) do
      nil ->
        {:reply, {:error, "Usuario no encontrado."}, estado}

      entrenador ->
        sobre_encontrado =
          cond do
            id_str == "ultimo" -> List.last(entrenador.sobres)
            true ->
              id_buscado = String.to_integer(id_str)
              Enum.find(entrenador.sobres, fn sobre -> sobre.id == id_buscado end)
          end

        if sobre_encontrado do
          nuevos_sobres = Enum.reject(entrenador.sobres, &(&1.id == sobre_encontrado.id))
          entrenador_actualizado = %{entrenador | sobres: nuevos_sobres}
          nuevo_estado = Map.put(estado, usuario, entrenador_actualizado)
          persistir(nuevo_estado)
          {:reply, {:ok, sobre_encontrado}, nuevo_estado}
        else
          {:reply, {:error, "Sobre no encontrado."}, estado}
        end
    end
  end

  @impl true
  def handle_call({:get_entrenador, usuario}, _from, estado) do
    {:reply, Map.get(estado, usuario), estado}
  end

  @impl true
  def handle_call({:transferir_pokemon, de, hacia, id_pokemon}, _from, estado) do
    with %{} = entrenador_origen  <- Map.get(estado, de),
         %{} = entrenador_destino <- Map.get(estado, hacia),
         pokemon when pokemon != nil <- Enum.find(entrenador_origen.inventario, &(&1.id == id_pokemon)) do
      entrenador_origen_actualizado  = %{entrenador_origen  | inventario: Enum.reject(entrenador_origen.inventario, &(&1.id == id_pokemon))}
      entrenador_destino_actualizado = %{entrenador_destino | inventario: entrenador_destino.inventario ++ [pokemon]}
      nuevo_estado = estado |> Map.put(de, entrenador_origen_actualizado) |> Map.put(hacia, entrenador_destino_actualizado)
      persistir(nuevo_estado)
      {:reply, {:ok, pokemon}, nuevo_estado}
    else
      _ -> {:reply, {:error, "No se pudo realizar la transferencia."}, estado}
    end
  end

  @impl true
  def handle_call({:get_equipo_activo, usuario}, _from, estado) do
    case Map.get(estado, usuario) do
      nil -> {:reply, nil, estado}
      entrenador ->
        case entrenador.equipo_activo do
          nil -> {:reply, nil, estado}
          nombre_equipo ->
            ids_pokemon = Map.get(entrenador.equipos, nombre_equipo, [])
            pokemon_del_equipo = Enum.filter(entrenador.inventario, fn pokemon -> pokemon.id in ids_pokemon end)
            {:reply, pokemon_del_equipo, estado}
        end
    end
  end

  @impl true
  def handle_cast({:agregar_pokemon, usuario, pokemon}, estado) do
    case Map.get(estado, usuario) do
      nil -> {:noreply, estado}
      entrenador ->
        entrenador_actualizado = %{entrenador | inventario: entrenador.inventario ++ [pokemon]}
        nuevo_estado = Map.put(estado, usuario, entrenador_actualizado)
        persistir(nuevo_estado)
        {:noreply, nuevo_estado}
    end
  end

  @impl true
  def handle_cast({:agregar_sobre, usuario, sobre}, estado) do
    case Map.get(estado, usuario) do
      nil -> {:noreply, estado}
      entrenador ->
        entrenador_actualizado = %{entrenador | sobres: entrenador.sobres ++ [sobre]}
        nuevo_estado = Map.put(estado, usuario, entrenador_actualizado)
        persistir(nuevo_estado)
        {:noreply, nuevo_estado}
    end
  end

  @impl true
  def handle_cast({:recompensar_batalla, ganador, perdedor}, estado) do
    nuevo_estado =
      estado
      |> actualizar_recompensa(ganador, 100)
      |> actualizar_recompensa(perdedor, 30)
      |> actualizar_victorias(ganador)

    persistir(nuevo_estado)
    {:noreply, nuevo_estado}
  end

  # ─── Helpers privados ────────────────────────────────────────────────────────

  defp actualizar_recompensa(estado, usuario, monto) do
    case Map.get(estado, usuario) do
      nil -> estado
      entrenador ->
        entrenador_actualizado = %{entrenador |
          monedas_actuales:   entrenador.monedas_actuales   + monto,
          monedas_acumuladas: entrenador.monedas_acumuladas + monto
        }
        Map.put(estado, usuario, entrenador_actualizado)
    end
  end

  defp actualizar_victorias(estado, usuario) do
    case Map.get(estado, usuario) do
      nil -> estado
      entrenador -> Map.put(estado, usuario, %{entrenador | victorias: entrenador.victorias + 1})
    end
  end

  defp todos_en_inventario?(inventario, ids) do
    ids_en_inventario = Enum.map(inventario, & &1.id)
    Enum.all?(ids, fn id -> id in ids_en_inventario end)
  end

  defp generar_sobre(tipo) do
    %{id: :rand.uniform(999_999), tipo: tipo}
  end

  defp persistir(estado) do
    lista = estado |> Map.values() |> Enum.map(&stringify/1)
    Persistencia.guardar_entrenadores(lista)
  end

  # Convierte átomos a strings para serialización JSON
  defp stringify(entrenador) do
    %{
      "usuario"            => entrenador.usuario,
      "clave"              => entrenador.clave,
      "victorias"          => entrenador.victorias,
      "monedas_actuales"   => entrenador.monedas_actuales,
      "monedas_acumuladas" => entrenador.monedas_acumuladas,
      "inventario"         => Enum.map(entrenador.inventario, &stringify_pokemon/1),
      "sobres"             => Enum.map(entrenador.sobres, fn sobre -> %{"id" => sobre.id, "tipo" => sobre.tipo} end),
      "equipos"            => entrenador.equipos |> Enum.into(%{}, fn {nombre, ids} -> {nombre, ids} end),
      "equipo_activo"      => entrenador.equipo_activo
    }
  end

  defp stringify_pokemon(pokemon) do
    %{
      "id"             => pokemon.id,
      "especie"        => pokemon.especie,
      "dueño_original" => pokemon.dueño_original,
      "rareza"         => pokemon.rareza,
      "ataque"         => pokemon.ataque,
      "defensa"        => pokemon.defensa,
      "velocidad"      => pokemon.velocidad,
      "tipos"          => pokemon.tipos,
      "movimientos"    => Enum.map(pokemon.movimientos, fn movimiento ->
        %{"nombre" => movimiento.nombre, "tipo" => movimiento.tipo, "poder_base" => movimiento.poder_base}
      end)
    }
  end

  # Convierte mapa con claves string (desde JSON) a mapa con átomos
  defp atomizar(entrenador_json) do
    %{
      usuario:            entrenador_json["usuario"],
      clave:              entrenador_json["clave"],
      victorias:          entrenador_json["victorias"] || 0,
      monedas_actuales:   entrenador_json["monedas_actuales"] || 0,
      monedas_acumuladas: entrenador_json["monedas_acumuladas"] || 0,
      inventario:         Enum.map(entrenador_json["inventario"] || [], &atomizar_pokemon/1),
      sobres:             Enum.map(entrenador_json["sobres"] || [], fn sobre -> %{id: sobre["id"], tipo: sobre["tipo"]} end),
      equipos:            entrenador_json["equipos"] || %{},
      equipo_activo:      entrenador_json["equipo_activo"]
    }
  end

  defp atomizar_pokemon(pokemon_json) do
    %{
      id:             pokemon_json["id"],
      especie:        pokemon_json["especie"],
      dueño_original: pokemon_json["dueño_original"],
      rareza:         pokemon_json["rareza"],
      ataque:         pokemon_json["ataque"],
      defensa:        pokemon_json["defensa"],
      velocidad:      pokemon_json["velocidad"],
      tipos:          pokemon_json["tipos"] || [],
      movimientos:    Enum.map(pokemon_json["movimientos"] || [], fn movimiento ->
        %{nombre: movimiento["nombre"], tipo: movimiento["tipo"], poder_base: movimiento["poder_base"]}
      end)
    }
  end
end
