# 📖 Manual de Usuario — Pokémon Battle Platform

> Plataforma de batallas Pokémon por turnos en consola, con colección, intercambios y batallas simultáneas.

---

## 🚀 Cómo iniciar el sistema

### Un solo nodo (modo local)
```bash
cd pokemon_battle
iex -S mix
```

### Dos nodos (modo distribuido)
```bash
# Terminal 1
iex --name arena@localhost --cookie pokemon_secret -S mix

# Terminal 2
iex --name arena2@localhost --cookie pokemon_secret -S mix
```
En Terminal 2, conectar los nodos:
```elixir
Node.connect(:"arena@localhost")
```

---

## 👤 SESIÓN

| Comando | Descripción |
|---------|-------------|
| `iniciar <usuario> <clave>` | Inicia sesión. Si no existe, crea la cuenta con 1 sobre básico gratis |
| `salir` | Cierra la sesión activa |
| `ayuda` | Muestra la lista de todos los comandos |

---

## 📊 PERFIL Y ESTADÍSTICAS

| Comando | Descripción |
|---------|-------------|
| `perfil` | Muestra monedas, sobres pendientes y cantidad de Pokémon |
| `inventario` | Lista todos tus Pokémon con ID, estadísticas y movimientos |
| `clasificacion` | Ranking global ordenado por victorias |

> El **ID del Pokémon** (ej: `#71834`) es necesario para crear equipos e intercambiar.

**Ejemplo de inventario:**
```
=== Inventario de Ana (2 Pokémon) ===
  1. [#71834] Pikachu (Electrico) [raro]
     Ataque: 63 | Defensa: 46 | Velocidad: 104 | Salud máx: 100
     Dueño original: Ana
     Movimientos: impactrueno(65), chispa(50), ataque_rapido(40), rafaga(60)
```

---

## 🛍️ TIENDA Y SOBRES

| Comando | Descripción |
|---------|-------------|
| `tienda` | Muestra tipos de sobre, precios y probabilidades |
| `comprar_sobre <tipo>` | Compra un sobre (`basico` o `avanzado`) |
| `abrir_sobre <id\|ultimo>` | Abre un sobre y recibe 3 Pokémon con movimientos |

**Precios y probabilidades:**

| Tipo | Precio | Común | Raro | Épico |
|------|--------|-------|------|-------|
| basico | 100 monedas | 70% | 25% | 5% |
| avanzado | 250 monedas | 40% | 45% | 15% |

**Rareza y estadísticas:**

| Rareza | Factor | Efecto |
|--------|--------|--------|
| común | 2% – 8% | Leve mejora sobre stats base |
| raro | 10% – 20% | Mejora moderada |
| épico | 25% – 40% | Mejora significativa |

Formula: `stat = round(stat_base × (1 + factor / 100))`

---

## ⚔️ EQUIPOS

| Comando | Descripción |
|---------|-------------|
| `listar_equipos` | Muestra todos tus equipos |
| `crear_equipo <nombre> <id1[,id2,id3]>` | Crea equipo de 1 a 3 Pokémon por ID |
| `usar_equipo <nombre>` | Carga el equipo para la siguiente batalla |
| `agregar_pokemon_equipo <equipo> <id>` | Agrega un Pokémon al equipo (máx. 3) |
| `quitar_pokemon_equipo <equipo> <id>` | Quita un Pokémon (no si es el único) |

---

## 🏟️ BATALLAS

| Comando | Descripción |
|---------|-------------|
| `listar_salas` | Ver salas disponibles |
| `crear_sala [tiempo_turno=N]` | Crear sala (default 20s por turno) |
| `unirse_sala <id_sala>` | Unirse a sala existente |
| `iniciar_batalla <id_sala>` | Iniciar batalla (requiere 2 jugadores con equipo) |
| `ataque <movimiento>` | Ejecutar movimiento del Pokémon activo |
| `cambiar <id_pokemon>` | Cambiar Pokémon activo |
| `rendirse` | Rendición inmediata |

**Reglas del turno:**
- Ambos actúan **simultáneamente**: envías tu acción y el sistema espera al rival.
- El Pokémon con **mayor velocidad** actúa primero.
- Si el primer ataque debilita al rival, el segundo **no actúa ese turno**.
- Sin acción en el tiempo límite → tu acción es **pasar**.
- Desconexión de más de 15s → **derrota por abandono**.

**Recompensas:** Ganador +100 monedas | Perdedor +30 monedas.

---

## 🔄 INTERCAMBIO

| Comando | Descripción |
|---------|-------------|
| `crear_sala_intercambio` | Crea sala y muestra código (ej. `IC-001`) |
| `unirse_sala_intercambio <codigo>` | El segundo entrenador se une |
| `ofrecer_pokemon <id>` | Propone el Pokémon a intercambiar |
| `confirmar_intercambio` | Confirma (se ejecuta cuando ambos confirman) |
| `cancelar_intercambio` | Cancela y cierra la sala para ambos |

---

## 📐 SISTEMA DE DAÑO

```
daño_base  = trunc((poder × (ataque_atacante / defensa_defensor)) / 5 + 2)
daño_final = trunc(daño_base × efectividad × stab × factor_aleatorio)
```

| Tipo ataca | Es fuerte contra (×2.0) |
|------------|------------------------|
| Fuego | Planta, Hielo, Bicho |
| Agua | Fuego, Roca, Tierra |
| Planta | Agua, Roca, Tierra |
| Eléctrico | Agua, Volador |
| Roca | Fuego, Hielo, Volador, Bicho |

- Débil (inversa) → ×0.5 | Neutro → ×1.0 | Doble tipo: se multiplican.
- **STAB** (mismo tipo atacante-movimiento) → ×1.5
- **Factor aleatorio**: 0.85 – 1.00. Daño mínimo siempre = **1**.

---

## 💾 PERSISTENCIA

| Archivo | Contenido |
|---------|-----------|
| `data/trainers.json` | Entrenadores, inventario, monedas, equipos |
| `data/pokemon.json` | Catálogo de especies base |
| `data/moves.json` | Pool de movimientos por tipo |
| `data/tienda.json` | Tipos de sobre y probabilidades |
| `data/battles.log` | Historial de batallas |

---

## ⚠️ Errores comunes

| Mensaje | Solución |
|---------|----------|
| `Contraseña incorrecta` | Verifica la clave |
| `Monedas insuficientes` | Gana batallas para obtener monedas |
| `Sobre no encontrado` | Usa `perfil` para ver tus sobres pendientes |
| `No tienes equipo cargado` | Ejecuta `usar_equipo <nombre>` antes de iniciar |
| `Pokémon faltantes en inventario` | Actualiza tu equipo tras un intercambio |
| `Sala ya tiene 2 jugadores` | Crea una nueva sala |
