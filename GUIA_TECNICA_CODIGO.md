# 🔬 Guía Técnica del Código — Pokémon Battle

> Explicación de conceptos Elixir utilizados en el proyecto, con ejemplos de líneas concretas del código para facilitar el estudio.

---

## 1. `use GenServer` — ¿Qué es un GenServer?

**Aparece en:** `gestor_entrenadores.ex`, `batalla.ex`, `gestor_salas.ex`, `intercambio.ex`, `servidor.ex`

Un **GenServer** (Generic Server) es un proceso OTP que mantiene estado en memoria y responde mensajes de forma controlada. Es el equivalente Elixir de una clase con métodos, pero ejecutándose en su propio proceso concurrente.

```elixir
use GenServer
```

Esto inyecta comportamientos predefinidos: `init/1`, `handle_call/3`, `handle_cast/2`, `handle_info/2`.

| Función       | Cuándo se usa                                                  |
| ------------- | -------------------------------------------------------------- |
| `handle_call` | Para mensajes **síncronos** (el llamador espera respuesta)     |
| `handle_cast` | Para mensajes **asíncronos** (el llamador no espera respuesta) |
| `handle_info` | Para mensajes del sistema (timers, señales de procesos, etc.)  |

**Ejemplo del proyecto:**

```elixir
# Llamada síncrona — el cliente ESPERA la respuesta
def handle_call({:perfil, usuario}, _from, estado) do
  # ... mostrar perfil ...
  {:reply, :ok, estado}
  #  ↑ respuesta  ↑ nuevo estado (lo que guarda el GenServer)
end

# Cast asíncrono — el cliente NO espera
def handle_cast({:agregar_pokemon, usuario, pokemon}, estado) do
  # ... agregar al inventario ...
  {:noreply, nuevo_estado}
  #            ↑ nuevo estado guardado internamente
end
```

---

## 2. `use DynamicSupervisor` — Supervisor Dinámico

**Aparece en:** `supervisor_batallas.ex`

Un **DynamicSupervisor** crea y supervisa procesos hijos **en tiempo de ejecución**. Si un proceso hijo falla, el supervisor lo reinicia sin afectar a los demás.

```elixir
use DynamicSupervisor

def init(:ok),
  do: DynamicSupervisor.init(strategy: :one_for_one)
# :one_for_one → si un hijo falla, solo ESE hijo se reinicia
```

```elixir
# Crear un nuevo proceso hijo (batalla) en tiempo de ejecución
def iniciar_batalla(config) do
  spec = {PokemonBattle.Batalla, config}
  DynamicSupervisor.start_child(__MODULE__, spec)
end
```

Cada batalla vive en su propio proceso aislado: si una falla, el sistema sigue funcionando.

---

## 3. `use Application` — Punto de entrada OTP

**Aparece en:** `application.ex`

Define el **árbol de supervisión** que arranca con la aplicación.

```elixir
def start(_type, _args) do
  children = [
    {PokemonBattle.SupervisorBatallas, []},
    {PokemonBattle.GestorEntrenadores, []},
    {PokemonBattle.GestorSalas, []},
    {PokemonBattle.Servidor, []}
  ]
  opts = [strategy: :one_for_one, name: PokemonBattle.Supervisor]
  Supervisor.start_link(children, opts)
end
```

Los procesos en `children` se arrancan en orden y se supervisan automáticamente.

---

## 4. El operador `|>` (Pipe)

**Aparece en:** todos los módulos

Pasa el resultado de una expresión como **primer argumento** de la siguiente función.

```elixir
# Sin pipe — difícil de leer
Enum.join(Enum.map(Map.values(estado), &stringify/1), ", ")

# Con pipe — se lee de arriba hacia abajo
estado
|> Map.values()
|> Enum.map(&stringify/1)
|> Enum.join(", ")
```

**Ejemplo del proyecto** (`gestor_entrenadores.ex`):

```elixir
ranking =
  estado
  |> Map.values()                                          # lista de entrenadores
  |> Enum.sort_by(fn entrenador ->                         # ordenar por victorias
       {-entrenador.victorias, -entrenador.monedas_acumuladas}
     end)
```

---

## 5. Pattern Matching en `case` y funciones

**Aparece en:** todos los módulos

Elixir compara la **estructura** de los datos, no solo su valor.

```elixir
def handle_call({:iniciar_sesion, usuario, clave}, _from, estado) do
  case Map.get(estado, usuario) do
    nil ->
      # El usuario no existe → registrar
      ...
    %{clave: ^clave} ->
      # El usuario existe Y la clave coincide (^clave = pin operator)
      {:reply, {:ok, "¡Bienvenido!"}, estado}
    _ ->
      # Cualquier otro caso → clave incorrecta
      {:reply, {:error, "Contraseña incorrecta."}, estado}
  end
end
```

El símbolo `^` (pin operator) fija el valor de una variable existente para comparar:

```elixir
clave = "1234"
^clave  # no asigna, COMPARA: solo coincide si el valor es "1234"
```

---

## 6. `with` — Encadenamiento de operaciones que pueden fallar

**Aparece en:** `gestor_entrenadores.ex`, `intercambio.ex`

Ejecuta pasos en secuencia. Si **alguno falla**, salta al bloque `else`.

```elixir
# En transferir_pokemon (gestor_entrenadores.ex)
with %{} = entrenador_origen  <- Map.get(estado, de),
     %{} = entrenador_destino <- Map.get(estado, hacia),
     pokemon when pokemon != nil <- Enum.find(entrenador_origen.inventario, &(&1.id == id)) do
  # Solo llega aquí si los 3 pasos tuvieron éxito
  {:reply, {:ok, pokemon}, nuevo_estado}
else
  # Si cualquier paso falló (devolvió nil u otro valor no esperado)
  _ -> {:reply, {:error, "No se pudo realizar la transferencia."}, estado}
end
```

---

## 7. `&` — Capture Operator (función anónima corta)

**Aparece en:** múltiples módulos

Crea funciones anónimas de forma abreviada. El `&1` representa el primer argumento.

```elixir
# Forma larga
Enum.filter(inventario, fn pokemon -> pokemon.id == id end)

# Forma corta con capture operator
Enum.filter(inventario, &(&1.id == id))
#                        ↑ primer argumento de la función anónima

# También sirve para referenciar funciones con nombre
Enum.map(entrenadores, &stringify/1)
#                      ↑ pasa la función stringify como argumento
```

---

## 8. `cond` — Múltiples condiciones sin anidación

**Aparece en:** `gestor_entrenadores.ex`, `batalla.ex`, `motor_combate.ex`

Es como un `if/else if`. Evalúa condiciones en orden y ejecuta la primera verdadera.

```elixir
cond do
  equipo_jugador1 == nil or equipo_jugador1 == [] ->
    IO.puts("[Error] #{jugador1} no tiene equipo cargado.")
    {:reply, :error, estado}

  equipo_jugador2 == nil or equipo_jugador2 == [] ->
    IO.puts("[Error] #{jugador2} no tiene equipo cargado.")
    {:reply, :error, estado}

  true ->
    # caso por defecto (siempre verdadero)
    iniciar_la_batalla()
end
```

---

## 9. `ETS` — Tabla en memoria compartida entre procesos

**Aparece en:** `intercambio.ex`

**ETS** (Erlang Term Storage) es una tabla en memoria que múltiples procesos pueden leer y escribir simultáneamente.

```elixir
@tabla_intercambios :intercambios_activos

# Crear la tabla (solo una vez)
:ets.new(@tabla_intercambios, [:named_table, :public, :set])
# :named_table → accesible por nombre desde cualquier proceso
# :public      → cualquier proceso puede leer/escribir
# :set         → cada clave es única (como un mapa)

# Insertar un registro: {codigo_sala -> pid_del_proceso}
:ets.insert(@tabla_intercambios, {codigo, self()})

# Buscar por clave
case :ets.lookup(@tabla_intercambios, codigo) do
  [{_codigo, pid_sala}] -> pid_sala   # encontrado
  []                    -> nil         # no existe
end

# Eliminar un registro
:ets.delete(@tabla_intercambios, codigo)
```

---

## 10. `Process.send_after` — Timer interno

**Aparece en:** `batalla.ex`

Envía un mensaje al proceso después de N milisegundos. Se usa para el timeout de turno.

```elixir
# Inicia un timer: enviará :timeout_turno al proceso actual en N segundos
referencia_timer = Process.send_after(self(), :timeout_turno, estado.tiempo_turno * 1_000)
#                                     ↑ pid   ↑ mensaje       ↑ milisegundos

# Cancelar el timer si ambos jugadores actuaron antes del límite
Process.cancel_timer(referencia_timer)

# El mensaje llega a handle_info cuando vence el tiempo
def handle_info(:timeout_turno, estado) do
  # Se ejecuta automáticamente cuando vence el tiempo
  ...
end
```

---

## 11. `spawn_link` — Crear proceso enlazado

**Aparece en:** `servidor.ex`

Crea un nuevo proceso. `spawn_link` lo **enlaza** al proceso actual: si uno muere, el otro también.

```elixir
def init(:ok) do
  # Lanza el loop CLI en proceso separado para no bloquear el GenServer
  spawn_link(fn -> loop(nil) end)
  {:ok, %{}}
end
```

Sin `spawn_link`, el `IO.gets("")` bloquearía el GenServer y no podría procesar otros mensajes.

---

## 12. `MapSet` — Conjunto sin duplicados

**Aparece en:** `intercambio.ex`

Un `MapSet` garantiza que **no hay elementos repetidos**.

```elixir
# Crear un conjunto vacío
confirmado: MapSet.new()

# Agregar un elemento (si ya existe, no cambia nada)
confirmados_actualizados = MapSet.put(estado.confirmado, usuario)

# Verificar si un elemento está en el conjunto
MapSet.member?(confirmados_actualizados, usuario)  # true o false
```

Se usa para rastrear qué jugadores confirmaron el intercambio.

---

## 13. `Enum.into` — Convertir enumerable a otra estructura

**Aparece en:** `gestor_entrenadores.ex`

```elixir
# Convierte lista de entrenadores JSON a mapa %{nombre -> entrenador}
estado = Enum.into(entrenadores, %{}, fn entrenador_json ->
  {entrenador_json["usuario"], atomizar(entrenador_json)}
  # ↑ clave                    ↑ valor
end)
# Resultado: %{"Ana" => %{usuario: "Ana", ...}, "Luis" => %{...}}
```

---

## 14. `trunc` vs `round` — Truncar y redondear decimales

**Aparece en:** `motor_combate.ex`

```elixir
trunc(13.9)   # → 13  (elimina la parte decimal, NO redondea)
trunc(7.01)   # → 7
round(13.5)   # → 14  (redondea al más cercano)
```

La fórmula de daño usa `trunc` porque el spec lo define así:

```elixir
dano_base  = trunc((poder_movimiento * (ataque_atacante / defensa_defensor)) / 5 + 2)
dano_final = trunc(dano_base * efectividad * stab * factor_aleatorio)
```

---

## 15. `@impl true` — Marcar implementaciones de callbacks

**Aparece en:** todos los módulos con GenServer

Le dice al compilador que la función es un **callback oficial** de un behaviour. Si el nombre es incorrecto, el compilador avisa.

```elixir
@impl true
def handle_call({:perfil, usuario}, _from, estado) do
  # Esto es reconocido como callback oficial de GenServer
end
```

---

## 16. Strings con `<>` y pattern matching de prefijo

**Aparece en:** `servidor.ex`

`<>` concatena strings. En pattern matching extrae el **sufijo** de un string con cierto prefijo.

```elixir
# Coincide con cualquier string que empiece con "iniciar "
# y extrae el resto en la variable `resto`
defp despachar("iniciar " <> resto, _sesion) do
  # Si el usuario escribe "iniciar Ana 1234"
  # resto = "Ana 1234"
  case String.split(resto) do
    [usuario, clave] -> ...
  end
end
```

---

## 17. `Jason` — Serialización JSON

**Aparece en:** `persistencia.ex`

Librería para codificar y decodificar JSON.

```elixir
# Leer JSON → mapa Elixir (claves son Strings)
{:ok, contenido} = File.read("data/trainers.json")
{:ok, data}      = Jason.decode(contenido)
# data = %{"usuario" => "Ana", ...}   ← claves String, NO átomos

# Mapa Elixir → escribir JSON
contenido = Jason.encode!(data, pretty: true)
File.write!("data/trainers.json", contenido)
```

> Por eso existe la función `atomizar/1`: convierte `%{"usuario" => "Ana"}` en `%{usuario: "Ana"}`.

---

## 18. `Enum.reduce` — Acumular un resultado sobre una lista

**Aparece en:** `motor_combate.ex`

Recorre una lista acumulando un resultado. Aquí se usa para multiplicar los modificadores de efectividad de un Pokémon con doble tipo.

```elixir
Enum.reduce(tipos_defensor, 1.0, fn tipo_defensor, modificador_acumulado ->
  modificador =
    cond do
      fuerte_contra?(tipo_movimiento, tipo_defensor) -> 2.0  # fuerte
      fuerte_contra?(tipo_defensor, tipo_movimiento) -> 0.5  # débil
      true -> 1.0                                            # neutro
    end
  modificador_acumulado * modificador   # ← se multiplica cada tipo
end)
# Geodude (Roca/Tierra) vs Agua: 2.0 * 2.0 = 4.0
```

---

## 19. `restart: :temporary` en GenServer

**Aparece en:** `batalla.ex`, `intercambio.ex`

Controla qué pasa cuando el proceso muere:

| Valor        | Significado                           |
| ------------ | ------------------------------------- |
| `:permanent` | Siempre se reinicia (default)         |
| `:temporary` | **Nunca se reinicia** automáticamente |
| `:transient` | Solo se reinicia si terminó con error |

```elixir
use GenServer, restart: :temporary
```

Las batallas usan `:temporary` porque al terminar normalmente no deben reiniciarse.

---

## 20. `hd` y `tl` — Cabeza y cola de una lista

**Aparece en:** `batalla.ex`

```elixir
hd([a, b, c])  # → a        (head = primer elemento)
tl([a, b, c])  # → [b, c]   (tail = resto de la lista)

# En batalla.ex: el primer Pokémon del equipo es el activo inicial
activo1: hd(equipo1).id
```

Si la lista está vacía, `hd` lanza un error. Por eso se valida que el equipo no esté vacío antes.

---

## 📁 Resumen de archivos y su función

| Archivo                  | Función principal                                       |
| ------------------------ | ------------------------------------------------------- |
| `application.ex`         | Arranca el árbol OTP (punto de entrada)                 |
| `servidor.ex`            | Lee comandos de consola y los enruta al módulo correcto |
| `gestor_entrenadores.ex` | Mantiene el estado de todos los entrenadores en memoria |
| `sistema_sobres.ex`      | Lógica de tienda, compra y apertura de sobres           |
| `motor_combate.ex`       | Fórmulas de daño, efectividad de tipos y STAB           |
| `batalla.ex`             | GenServer de una batalla activa (uno por batalla)       |
| `supervisor_batallas.ex` | Crea y supervisa procesos de batalla e intercambio      |
| `gestor_salas.ex`        | Registro de salas de batalla disponibles                |
| `intercambio.ex`         | GenServer de sala de intercambio en tiempo real         |
| `persistencia.ex`        | Lectura y escritura de archivos JSON                    |
| `cluster.ex`             | Selección de nodo para batallas distribuidas            |
