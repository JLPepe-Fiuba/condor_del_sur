# Sistema de Reservas — Cóndor del Sur

**TP1 — Taller de Programación — Cátedra Camejo**
Pepe, Jonathan Leonel — Padrón 94.692

Sistema de reserva de asientos para la aerolínea ficticia "Cóndor del Sur".
Implementado en Elixir usando procesos manuales sin OTP.

- **Enunciado oficial del dominio del problema**: https://hackmd.io/@7k6x0-lQSIe6vtz2KwjLAw/SkaAPM4pbx

---

## Compilar el proyecto

```bash
mix compile
```

## Correr los Test

```bash
mix test
```

## Correr la Demo

```bash
iex -S mix
```

```elixir
Demo.run()
```

La demo dura aproximadamente 35 segundos porque incluye un caso de expiración automática de reserva con segundos reales de espera.

---

## Procesos del sistema

- **FlightServer** (`lib/flight_server.ex`): Es el proceso central del sistema. Mantiene el estado completo del vuelo: asientos, pasajeros y reservas. Es el único dueño del `%Flight{}` y el único que puede modificarlo. Todos los demás procesos interactúan con él enviando mensajes.

- **AuditServer** (`lib/audit_server.ex`): Proceso secundario que registra todos los eventos del sistema con timestamp. Acumula los eventos y puede escribirlos a disco cuando se le pide.

- **Workers de expiración**: Cada vez que se inicia una reserva, `FlightServer` lanza un proceso worker que espera 30 segundos y luego envía `{:expire_reservation, reservation_id}` de vuelta al servidor. Si la reserva ya fue confirmada o cancelada, el mensaje se ignora sin efecto. Estos procesos hacen su trabajo y terminan solos.

## Concurrencia

El `%Flight{}` vive dentro de `FlightServer` y solo ese proceso puede modificarlo. Los mensajes se procesan de a uno desde la mailbox, por lo que si dos pasajeros compiten por el mismo asiento, el segundo en ser atendido ya lo ve como `:reserved`. Además, `FlightServer` usa `Process.monitor` sobre cada worker de expiración que lanza. Finalmente, los procesos están registrados con nombre (`register`): 
- `FlightServer` como `:flight_server`.
- `AuditServer` como `:audit_server`.
Esto permite enviarles mensajes sin necesidad de guardar el PID.