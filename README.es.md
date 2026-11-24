<div align="center">

# ARTEX-Global Edición Termux

**Ejecuta ARTEX-Global completamente en Android vía Termux** — sin root requerido

[![license: AGPL-3.0](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE)
[![platform: Android](https://img.shields.io/badge/platform-Android%20%2B%20Termux-green.svg)](https://f-droid.org/packages/com.termux/)

</div>

---

> ⚠️ **Advertencia de Seguridad y Uso Indebido — Léala Primero**
>
> **Este repositorio se publica únicamente para su uso en entornos autorizados y solo para desarrollar capacidades de defensa y detección.**
>
> ARTEX es una herramienta ofensiva autónoma lo bastante potente como para llevar un ataque desde el reconocimiento, pasando por la intrusión, hasta la exfiltración de datos con muy poca intervención humana, de modo que el daño derivado de su uso indebido es igual de grande. Esta edición Termux no se publica para ayudar a los atacantes. Su objetivo es ayudar a los defensores a entender cómo funcionan estos ataques autónomos de IA y a desarrollar la capacidad de detectarlos y bloquearlos.
>
> - **El uso no autorizado es un delito en sí mismo.** No ejecute ningún escaneo, sondeo ni explotación contra sistemas que no sean de su propiedad o para los que no cuente con autorización explícita por escrito.
> - **No dirija el ataque a servicios en producción ni a activos de terceros.** Verifique únicamente en entornos de aprendizaje, investigación y aislados localmente que sean de su propiedad (objetivos deliberadamente vulnerables como OWASP Juice Shop o DVWA).
> - **Léalo desde el punto de vista del defensor.** Este repositorio también reúne material de defensa y detección, como firmas de detección y listas de verificación de endurecimiento, para los ataques autónomos de IA. → **[Guía de defensa y detección](artex-global/docs/defense-es.md)** (también en [inglés](artex-global/docs/defense-en.md), [coreano](artex-global/docs/defense-ko.md))
>
> Si no está de acuerdo con esta advertencia ni con las [restricciones de uso y el descargo de responsabilidad](#licencia-y-descargo-de-responsabilidad) que figuran más abajo, no descargue ni utilice este repositorio.

---

## Qué Es Esto

Esta es una **adaptación nativa para Termux** de [ARTEX-Global](https://github.com/jiwoochris/artex-global) — un sistema autónomo de pruebas de penetración impulsado por multiagentes LLM (backend en Go + frontend en Next.js).

- ✅ **Ejecuta nativamente en Android** vía Termux (binario ARM64, sin emulación)
- ✅ **Binario único** con frontend Next.js embebido
- ✅ **PostgreSQL** se ejecuta localmente en el dispositivo
- ✅ **Todas las herramientas nativas** (nmap, ripgrep, curl, etc. vía paquetes Termux)
- ✅ **Sistema de skills** incluido (api-recon, playwright-cli, termux-netdiscover, etc.)
- ✅ **Reglas de detección** (Sigma, Suricata, ATT&CK) incluidas para investigación defensiva

> **Basado en**: [jiwoochris/artex-global](https://github.com/jiwoochris/artex-global) (AGPL-3.0)  
> **Upstream**: [Autumn-27/ARTEX](https://github.com/Autumn-27/ARTEX) (AGPL-3.0)

---

## Inicio Rápido

### Prerrequisitos

- **Termux** desde [F-Droid](https://f-droid.org/packages/com.termux/) o GitHub (NO Play Store)
- **Android 7.0+** (API 24+)
- **Mínimo 4GB RAM** (8GB+ recomendado para operaciones LLM)
- **Permiso de almacenamiento** concedido: `termux-setup-storage`

### Instalación en Un Comando

```bash
# 1. Clona este repo
cd ~/hack
git clone https://github.com/DevMaker-face/artex-global-termux.git
cd artex-global-termux

# 2. Ejecuta el setup (instala Go, Node.js, PostgreSQL, compila ARTEX)
chmod +x artex-termux-setup.sh
./artex-termux-setup.sh

# 3. Inicia ARTEX
~/run-artex.sh

# 4. Abre el navegador en http://127.0.0.1:8787
#    Primera visita: ve a /setup, ingresa el token de configuración desde los logs
```

---

## Estructura de Directorios

```
~/hack/artex-global-termux/   # Este repo (fuente)
~/artex-global/               # Binario compilado + fuente (enlazado desde setup)
~/artex-data/                 # Datos en tiempo de ejecución (creado por setup)
├── config.json               # Configuración
├── postgres/                 # Directorio de datos PostgreSQL
├── postgres.log              # Logs de PostgreSQL
├── skills/                   # Directorio de skills
├── start-postgres.sh         # Gestión de PostgreSQL
├── stop-postgres.sh
├── setup-db.sh
└── start-artex.sh            # Script daemon ARTEX
~/run-artex.sh                # Comando principal de inicio
~/stop-artex.sh               # Detiene todo
~/update-artex.sh             # Actualiza a la última versión
```

---

## Configuración

### Variables de Entorno

| Variable | Por Defecto | Descripción |
|----------|-------------|-------------|
| `ARTEX_BIND` | `127.0.0.1:8787` | Dirección de enlace para la UI web |
| `ARTEX_PROXY` | `127.0.0.1:8788` | Puerto del proxy de tráfico |
| `ARTEX_CONFIG` | `~/artex-data/config.json` | Ruta del archivo de configuración |
| `ARTEX_PG_DSN` | Auto desde config | Cadena de conexión PostgreSQL |
| `ARTEX_SKILL_DIR` | `~/artex-data/skills` | Directorio de skills |
| `ANTHROPIC_API_KEY` | - | Para modelos Claude |
| `OPENAI_API_KEY` | - | Para modelos OpenAI |

### Archivo de Configuración (`~/artex-data/config.json`)

```json
{
  "database": {
    "host": "127.0.0.1",
    "port": 5432,
    "user": "artex",
    "password": "artex",
    "dbname": "artex",
    "sslmode": "disable"
  },
  "skill_dir": "/data/data/com.termux/files/home/artex-data/skills",
  "language": "es"
}
```

---

## Ejecutar ARTEX

### Primer Plano (ver logs)
```bash
~/run-artex.sh
```

### Segundo Plano (persistente)
```bash
nohup ~/run-artex.sh > ~/artex.log 2>&1 &
echo $! > ~/artex.pid
```

### Dirección de Enlace Personalizada (Acceso LAN)
```bash
# Enlazar a todas las interfaces
ARTEX_BIND=0.0.0.0:8787 ~/run-artex.sh

# O con argumentos explícitos
~/run-artex.sh -addr 0.0.0.0:8787 -proxy 0.0.0.0:8788
```

### Detener ARTEX
```bash
~/stop-artex.sh
```

---

## Configuración Inicial

1. Inicia ARTEX: `~/run-artex.sh`
2. Revisa los logs para el token de configuración:
   ```bash
   grep "Setup token" ~/artex.log
   # O si ejecuta en primer plano, revisa la salida del terminal
   ```
3. Abre el navegador en `http://127.0.0.1:8787/setup`
4. Ingresa el token de configuración y crea la contraseña de administrador
5. Configura los ajustes LLM en **Sistema → Ajustes → Configuración LLM**

---

## Configuración LLM

ARTEX soporta múltiples proveedores LLM:

### Anthropic (Claude) — Recomendado
```bash
export ANTHROPIC_API_KEY=sk-ant-...
# O configúralo en la UI: Sistema → Ajustes → Configuración LLM
```

### OpenAI / Compatible con OpenAI
```bash
export OPENAI_API_KEY=sk-...
export ARTEX_LLM_BASE_URL=https://api.openai.com/v1  # O tu proxy
# Configura el modelo en la UI o via ARTEX_LLM_MODEL
```

### Modelos Locales (Ollama, etc.)
```bash
export ARTEX_LLM_BASE_URL=http://127.0.0.1:11434/v1
export ARTEX_LLM_MODEL=llama3.1:70b
export OPENAI_API_KEY=dummy  # Requerido pero no usado
```

---

## Actualización

```bash
~/update-artex.sh
```

Esto hará:
1. Detener ARTEX y PostgreSQL
2. Descargar los últimos cambios de GitHub
3. Reconstruir el frontend (exportación estática Next.js)
4. Recompilar el binario Go para android/arm64
5. Actualizar el directorio de skills
6. Reiniciar listo para `~/run-artex.sh`

---

## Solución de Problemas

### PostgreSQL No Inicia
```bash
# Revisa los logs
cat ~/artex-data/postgres.log

# Solución común: eliminar lock obsoleto
rm -f ~/artex-data/postgres/postmaster.pid
~/artex-data/start-postgres.sh
```

### Fallo de Compilación - Versión de Go
```bash
go version
# Debe ser go1.26+
# Si no lo es, el script de setup lo instala automáticamente
```

### Fallo de Compilación - Versión de Node.js
```bash
node --version
# Debe ser v20+
# Usa nvm: nvm install 20 && nvm use 20
```

### Sin Memoria Durante la Compilación
```bash
# Aumentar swap (requiere root)
su -c "swapon /dev/block/zram0"  # Si zram está configurado
# O agregar archivo swap
dd if=/dev/zero of=/data/swap bs=1M count=2048
mkswap /data/swap
su -c "swapon /data/swap"
```

### Puerto Ya en Uso
```bash
# Encontrar y matar proceso en puerto 8787
pkill -f "artex.*-addr"
# O usar puerto diferente
~/run-artex.sh -addr 127.0.0.1:8789
```

### Binario No Encontrado
```bash
# Recompilar
cd ~/artex-global
export CGO_ENABLED=0 GOOS=android GOARCH=arm64
go build -tags embedui -trimpath -ldflags "-s -w" -o artex ./cmd/artex
```

---

## Notas de Rendimiento

- **Android/ARM64** el binario se ejecuta nativamente (sin emulación)
- **PostgreSQL** se ejecuta en el dispositivo — puede ser más lento que en escritorio
- **Llamadas API LLM** van por red — la latencia depende de la conexión
- **Frontend** son archivos estáticos embebidos — carga rápida
- **Herramientas** (nmap, ripgrep, etc.) son binarios nativos de Termux

---

## Consideraciones de Seguridad

⚠️ **Importante**: ARTEX es un framework de pruebas de penetración. Úselo solo contra:

- Sistemas de su propiedad
- Sistemas para los que tenga autorización explícita por escrito
- Entornos de prueba aislados (DVWA, Juice Shop, etc.)

La dirección de enlace por defecto es `127.0.0.1` por seguridad. Solo exponga a LAN después de:

1. Configuración inicial completa (contraseña de admin establecida)
2. Entender los riesgos
3. Estar en una red de confianza

---

## Auto-Inicio al Arranque (Opcional)

```bash
# Habilitar wake lock de Termux (evita suspensión)
termux-wake-lock

# Habilitar script de arranque
mv ~/.termux/boot/artex-boot.sh ~/.termux/boot/artex-boot.sh.enabled

# Deshabilitar
mv ~/.termux/boot/artex-boot.sh.enabled ~/.termux/boot/artex-boot.sh
termux-wake-unlock
```

---

## Logs

| Log | Ubicación |
|-----|-----------|
| ARTEX | `~/artex.log` (si usa nohup) o terminal |
| PostgreSQL | `~/artex-data/postgres.log` |
| Script de arranque | `~/artex-boot.log` |

---

## Desinstalación

```bash
~/stop-artex.sh
rm -rf ~/artex-global ~/artex-data ~/run-artex.sh ~/stop-artex.sh ~/update-artex.sh
rm -rf ~/.termux/boot/artex-boot.sh*
```

---

## Estructura del Repositorio

```
artex-global-termux/
├── artex-global/              # Fuente completa ARTEX-Global (tipo submódulo)
│   ├── agent/                 # Sistema multi-agente LLM (planner, worker, etc.)
│   ├── server/                # Servidor HTTP Go, API, auth, engine
│   ├── db/                    # Esquema y consultas PostgreSQL
│   ├── traffic/               # Proxy de grabación MITM
│   ├── intercept/             # Puerta de aprobación de herramientas
│   ├── detections/            # Reglas Sigma, Suricata, ATT&CK
│   ├── skills/                # Skills (api-recon, playwright, etc.)
│   ├── web/                   # Frontend Next.js (embebido)
│   └── ...                    # Ver artex-global/README.md
├── artex-termux-setup.sh      # Setup completo del entorno
├── install-artex-termux.sh    # Instalador rápido
├── start-artex.sh             # Script de inicio (usado por run-artex.sh)
├── stop-artex.sh              # Script de parada
├── config.example.json        # Configuración de ejemplo
├── skills/                    # Skills específicos de Termux
│   └── termux-netdiscover/    # Descubrimiento de red para Termux
├── README-TERMUX.md           # Guía detallada de Termux
├── ARTEX_SYSTEM_SPEC.md       # Especificación del sistema
└── DEVEX_SYSTEM_SPEC.md       # Especificación de experiencia de desarrollo
```

---

## Licencia y Descargo de Responsabilidad

### Licencia de Código Abierto

Este proyecto se distribuye bajo la **GNU Affero General Public License v3.0 (AGPL-3.0)**. Los términos completos están en el archivo [LICENSE](artex-global/LICENSE).

Cualquiera puede usarlo, modificarlo y distribuirlo libremente, pero **las obras derivadas también deben publicarse bajo AGPL-3.0.** En particular, si modifica este proyecto y **lo proporciona a usuarios a través de una red (por ejemplo, como servicio en línea), debe poner a disposición de esos usuarios el código fuente completo correspondiente.**

> ⚠️ **Importante:** una licencia de código abierto por sí sola no restringe cómo puede usarse el software. Las "Restricciones de uso" y el "Descargo de responsabilidad" de más abajo son un pacto adicional y un aviso serio que el autor original exige de los usuarios — por favor, obsérvelos.

### Restricciones de Uso

- Use esta herramienta para **leer y estudiar el código fuente**, y para **verificar sus principios técnicos en un entorno aislado localmente.**
- A menos que el objetivo sea de su propiedad o cuente con **autorización explícita por escrito**, no escanee, sondee, explote ni ataque ningún sitio web, servicio en línea ni sistema conectado.
- Usarla para intrusión ilegal, robo de datos, denegación de servicio (DoS) o cualquier otra actividad destructiva o delictiva está estrictamente prohibido.
- Debe cumplir todas las leyes sobre seguridad de redes, protección de datos y delitos informáticos de su país y región.

### Descargo de Responsabilidad

Este proyecto se proporciona **"TAL CUAL" (AS IS)**, sin garantía alguna, expresa o implícita. El autor original y los contribuidores no se hacen responsables de ningún daño directo o indirecto, pérdida de datos, daño al sistema ni disputa legal que surja del uso de esta herramienta (con independencia de si se usó de forma apropiada o no). **Descargar, instalar o usar este proyecto se considera que constituye haber leído, entendido y aceptado todas las condiciones anteriores.**

**Toda la responsabilidad legal y las consecuencias recaen sobre el usuario.**

---

## Upstream y Créditos

- **ARTEX Original**: [Autumn-27/ARTEX](https://github.com/Autumn-27/ARTEX) (actualmente inaccesible, comprobado 2026-10)
- **ARTEX-Global**: [jiwoochris/artex-global](https://github.com/jiwoochris/artex-global) — edición localizada (EN/KO/ZH/JA/ES)
- **SDK de Agentes**: [Autumn-27/norma](https://github.com/Autumn-27/norma)
- **Adaptación Termux**: Este repositorio

---

## Para Documentación Completa

Consulte la **documentación de ARTEX-Global** dentro de `artex-global/`:

- **README Principal**: [`artex-global/README.md`](artex-global/README.md) (Inglés)
- **Español**: [`artex-global/README.es.md`](artex-global/README.es.md)
- **한국어**: [`artex-global/README.ko.md`](artex-global/README.ko.md)
- **中文**: [`artex-global/README.zh.md`](artex-global/README.zh.md)
- **日本語**: [`artex-global/README.ja.md`](artex-global/README.ja.md)
- **Arquitectura**: [`artex-global/README.md#system-architecture`](artex-global/README.md#system-architecture)
- **Defensa y Detección**: [`artex-global/docs/defense-es.md`](artex-global/docs/defense-es.md)
- **Detecciones**: [`artex-global/detections/`](artex-global/detections/)
- **Changelog**: [`artex-global/CHANGELOG.es.md`](artex-global/CHANGELOG.es.md)
- **Contribuir**: [`artex-global/CONTRIBUTING.es.md`](artex-global/CONTRIBUTING.es.md)