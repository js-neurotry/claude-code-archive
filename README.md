# Claude Code Archive

Archivo permanente de conversaciones de Claude Code, convertidas de JSONL a Markdown navegable.

## Cómo funciona

```
~/.claude/projects/          claude-code-logs serve         ~/claude-code-logs/
(JSONL originales)    --->   (convierte a Markdown)   --->  (repo Git)
                                                              |
                                                        sanitize.sh
                                                        (redacta secrets)
                                                              |
                                                        git commit + push
                                                        (archivo permanente)
```

## Estructura

```
claude-code-logs/
├── auto-archive.ps1          # Script de automatización (pipeline completo)
├── sanitize.sh               # Redacción de API keys y secrets
├── .gitignore                # Proyectos excluidos
├── index.md                  # Índice general de proyectos
├── proyecto-a/
│   ├── index.md              # Índice de sesiones del proyecto
│   ├── uuid-sesion-1.md      # Conversación completa
│   └── uuid-sesion-2.md
└── proyecto-b/
    └── ...
```

## Uso manual

```bash
# 1. Generar Markdown desde los JSONL
claude-code-logs serve --dir ~/claude-code-logs

# 2. Sanitizar secrets antes de commitear
bash ~/claude-code-logs/sanitize.sh ~/claude-code-logs

# 3. Commit y push
cd ~/claude-code-logs
git add -A
git commit -m "Archivo: $(date +%Y-%m-%d)"
git push origin main
```

## Automatización

El script `auto-archive.ps1` ejecuta el pipeline completo:

1. **Symlinks** — Crea enlaces simbólicos necesarios para Windows (workaround)
2. **Genera Markdown** — Lanza `claude-code-logs serve` temporalmente
3. **Sanitiza** — Ejecuta `sanitize.sh` para redactar secrets
4. **Commit + push** — Solo si hay cambios nuevos

Está programado en Task Scheduler como `ClaudeCodeAutoArchive`, ejecutándose diariamente a medianoche con `StartWhenAvailable` (si la máquina está apagada, se recupera al encender).

### Gestión de la tarea programada

```powershell
# Verificar estado
Get-ScheduledTask -TaskName "ClaudeCodeAutoArchive"

# Ejecutar manualmente
Start-ScheduledTask -TaskName "ClaudeCodeAutoArchive"

# Eliminar
Unregister-ScheduledTask -TaskName "ClaudeCodeAutoArchive"
```

## Sanitización de secrets

`sanitize.sh` detecta y redacta automáticamente:

| Proveedor | Patrón |
|-----------|--------|
| OpenAI | `sk-proj-*`, `sk-live-*` |
| GitHub | `ghp_*`, `gho_*`, `ghs_*`, `github_pat_*` |
| AWS | `AKIA*` |
| Anthropic | `sk-ant-*` |
| Slack | `xox[bprs]-*` |
| Stripe | `sk_live_*`, `sk_test_*` |
| Google | `AIza*` |

Ejecutar independientemente:

```bash
bash sanitize.sh ~/claude-code-logs
```

## Workaround Windows

`claude-code-logs` fue diseñado para macOS/Linux donde los paths se codifican como `-Users-name-project`. En Windows se codifican como `C--Users-name-project` (sin guion inicial), lo que causa que la herramienta no los detecte.

**Solución**: `auto-archive.ps1` crea symlinks con prefijo `-` automáticamente en `~/.claude/projects/` antes de cada ejecución.

## Requisitos

- [Go](https://go.dev/dl/) (para instalar claude-code-logs)
- [claude-code-logs](https://github.com/fabriqaai/claude-code-logs) (`go install github.com/fabriqaai/claude-code-logs@latest`)
- Git
- Git Bash (incluido con Git for Windows, necesario para `sanitize.sh`)

## Comandos útiles

| Acción | Comando |
|--------|---------|
| Navegar logs en el browser | `claude-code-logs serve` |
| Puerto personalizado | `claude-code-logs serve --port 3000` |
| Forzar regeneración | `claude-code-logs serve --force` |
| Modo watch (tiempo real) | `claude-code-logs serve --watch` |
| Buscar en conversaciones | `grep -r "término" ~/claude-code-logs --include="*.md"` |
| Ver log de archivado | `cat ~/claude-code-logs/archive.log` |

## Referencias

- [claude-code-logs](https://github.com/fabriqaai/claude-code-logs)
- [Blog: Building a Permanent Archive of Every Claude Code Conversation](https://www.cengizhan.com/p/building-a-permanent-archive-of-every)
