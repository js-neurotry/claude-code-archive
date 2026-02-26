#!/bin/bash
# sanitize.sh - Redacta secrets de los archivos Markdown generados por claude-code-logs
# Uso: ./sanitize.sh [directorio]  (default: directorio actual)

DIR="${1:-.}"
FOUND=0

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Escaneando archivos .md en: $DIR"
echo "=================================="

# Patrones de secrets con su etiqueta de reemplazo
# Formato: "patron|etiqueta"
PATTERNS=(
  # OpenAI
  'sk-proj-[A-Za-z0-9_-]{20,}|[REDACTED-OPENAI-KEY]'
  'sk-live-[A-Za-z0-9_-]{20,}|[REDACTED-OPENAI-KEY]'
  'sk-[A-Za-z0-9]{40,}|[REDACTED-OPENAI-KEY]'
  # GitHub
  'ghp_[A-Za-z0-9]{36,}|[REDACTED-GITHUB-TOKEN]'
  'gho_[A-Za-z0-9]{36,}|[REDACTED-GITHUB-TOKEN]'
  'ghs_[A-Za-z0-9]{36,}|[REDACTED-GITHUB-TOKEN]'
  'github_pat_[A-Za-z0-9_]{20,}|[REDACTED-GITHUB-TOKEN]'
  # AWS
  'AKIA[0-9A-Z]{16}|[REDACTED-AWS-KEY]'
  # Anthropic
  'sk-ant-[A-Za-z0-9_-]{20,}|[REDACTED-ANTHROPIC-KEY]'
  # Slack
  'xox[bprs]-[A-Za-z0-9-]{10,}|[REDACTED-SLACK-TOKEN]'
  # Stripe
  'sk_live_[A-Za-z0-9]{20,}|[REDACTED-STRIPE-KEY]'
  'sk_test_[A-Za-z0-9]{20,}|[REDACTED-STRIPE-KEY]'
  # Google
  'AIza[A-Za-z0-9_-]{35}|[REDACTED-GOOGLE-KEY]'
  # Genéricos: "API_KEY=valor" o "api_key": "valor"
  '([Aa][Pp][Ii]_[Kk][Ee][Yy][\s]*[=:]["'"'"']\s*)([A-Za-z0-9_-]{20,})(["'"'"'])|\\1[REDACTED-API-KEY]\\3'
  '([Ss][Ee][Cc][Rr][Ee][Tt][\s]*[=:]["'"'"']\s*)([A-Za-z0-9_-]{20,})(["'"'"'])|\\1[REDACTED-SECRET]\\3'
)

# Procesar cada patrón
for entry in "${PATTERNS[@]}"; do
  pattern="${entry%%|*}"
  label="${entry##*|}"

  # Contar matches antes de reemplazar
  count=$(grep -rlE "$pattern" "$DIR" --include="*.md" 2>/dev/null | wc -l)

  if [ "$count" -gt 0 ]; then
    files=$(grep -rlE "$pattern" "$DIR" --include="*.md" 2>/dev/null)
    matches=$(grep -rEc "$pattern" "$DIR" --include="*.md" 2>/dev/null | awk -F: '{s+=$NF} END {print s}')
    echo -e "${RED}ENCONTRADO${NC}: $matches ocurrencias de patrón ${YELLOW}${label}${NC} en $count archivo(s)"

    # Mostrar archivos afectados
    echo "$files" | while read f; do
      echo "  -> $f"
    done

    # Reemplazar
    grep -rlE "$pattern" "$DIR" --include="*.md" 2>/dev/null | while read file; do
      sed -i -E "s|$pattern|$label|g" "$file"
    done

    FOUND=$((FOUND + 1))
  fi
done

echo "=================================="
if [ "$FOUND" -gt 0 ]; then
  echo -e "${YELLOW}Se redactaron $FOUND tipo(s) de secrets.${NC}"
  echo "Revisa los cambios con: git diff"
else
  echo -e "${GREEN}No se encontraron secrets. Todo limpio.${NC}"
fi
