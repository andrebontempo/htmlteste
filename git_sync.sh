#!/bin/bash

# ============================================================
# git_sync.sh
#
# Sincronização de ambiente local com GitHub
#
# USO:
#
#   ./git_sync.sh
#       Modo seguro.
#
#   ./git_sync.sh --push
#       Adiciona alterações, cria commit e envia para o GitHub.
#
#   ./git_sync.sh --stash
#       Guarda alterações locais no stash e sincroniza com GitHub.
#
#   ./git_sync.sh --force
#       DESCARTA alterações locais e deixa a cópia exatamente
#       igual ao GitHub.
#
#   ./git_sync.sh --help
#       Mostra esta ajuda.
#
# ============================================================

set -e

# ------------------------------------------------------------
# Cores
# ------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# ------------------------------------------------------------
# Funções
# ------------------------------------------------------------

erro() {
    echo -e "${RED}ERRO:${NC} $1"
    exit 1
}

info() {
    echo -e "${BLUE}==>${NC} $1"
}

sucesso() {
    echo -e "${GREEN}OK:${NC} $1"
}

aviso() {
    echo -e "${YELLOW}ATENÇÃO:${NC} $1"
}

# ------------------------------------------------------------
# Ajuda
# ------------------------------------------------------------

mostrar_ajuda() {

    echo
    echo "============================================================"
    echo "                  GIT SYNC"
    echo "============================================================"
    echo
    echo "Uso:"
    echo
    echo "  ./git_sync.sh"
    echo "      Sincronização segura."
    echo "      Não descarta alterações locais."
    echo
    echo "  ./git_sync.sh --push"
    echo "      Adiciona alterações, cria commit e faz push."
    echo
    echo "  ./git_sync.sh --stash"
    echo "      Guarda alterações no stash e sincroniza."
    echo
    echo "  ./git_sync.sh --force"
    echo "      DESCARTA alterações locais e deixa o código"
    echo "      exatamente igual ao GitHub."
    echo
    echo "  ./git_sync.sh --help"
    echo "      Mostra esta ajuda."
    echo
}

# ------------------------------------------------------------
# Verifica argumento
# ------------------------------------------------------------

MODO="safe"

case "${1:-}" in

    "")
        MODO="safe"
        ;;

    --push)
        MODO="push"
        ;;

    --stash)
        MODO="stash"
        ;;

    --force)
        MODO="force"
        ;;

    --help|-h)
        mostrar_ajuda
        exit 0
        ;;

    *)
        echo
        erro "Parâmetro desconhecido: $1

Use:

  ./git_sync.sh
  ./git_sync.sh --push
  ./git_sync.sh --stash
  ./git_sync.sh --force
  ./git_sync.sh --help"
        ;;

esac

# ------------------------------------------------------------
# Verifica se está dentro de um repositório Git
# ------------------------------------------------------------

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    erro "Este diretório não é um repositório Git."
fi

# ------------------------------------------------------------
# Vai para a raiz do repositório
# ------------------------------------------------------------

REPO_DIR=$(git rev-parse --show-toplevel)

cd "$REPO_DIR"

# ------------------------------------------------------------
# Informações do repositório
# ------------------------------------------------------------

BRANCH=$(git branch --show-current)

REMOTE=$(git remote get-url origin 2>/dev/null || true)

if [ -z "$BRANCH" ]; then
    erro "Não foi possível identificar a branch atual."
fi

if [ -z "$REMOTE" ]; then
    erro "O repositório não possui um remote chamado 'origin'."
fi

# ------------------------------------------------------------
# Cabeçalho
# ------------------------------------------------------------

echo
echo "============================================================"
echo "             SINCRONIZAÇÃO COM GITHUB"
echo "============================================================"
echo

echo -e "Diretório : ${CYAN}$REPO_DIR${NC}"
echo -e "Branch    : ${CYAN}$BRANCH${NC}"
echo -e "Remote    : ${CYAN}$REMOTE${NC}"
echo -e "Modo      : ${CYAN}$MODO${NC}"

echo

# ------------------------------------------------------------
# Atualiza informações do GitHub
# ------------------------------------------------------------

info "Consultando o GitHub..."

git fetch origin

sucesso "Informações do GitHub atualizadas."

# ------------------------------------------------------------
# Verifica se origin/BRANCH existe
# ------------------------------------------------------------

if ! git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
    erro "A branch 'origin/$BRANCH' não existe no GitHub."
fi

# ------------------------------------------------------------
# Função para verificar alterações locais
# ------------------------------------------------------------

tem_alteracoes() {

    if ! git diff --quiet; then
        return 0
    fi

    if ! git diff --cached --quiet; then
        return 0
    fi

    if [ -n "$(git ls-files --others --exclude-standard)" ]; then
        return 0
    fi

    return 1
}

# ------------------------------------------------------------
# Função para mostrar alterações
# ------------------------------------------------------------

mostrar_status() {

    echo
    echo "------------------------------------------------------------"
    echo "ALTERAÇÕES LOCAIS"
    echo "------------------------------------------------------------"

    git status --short

    echo
}

# ============================================================
# MODO PUSH
# ============================================================

if [ "$MODO" = "push" ]; then

    echo
    info "Modo PUSH selecionado."

    # --------------------------------------------------------
    # Verifica se existem alterações
    # --------------------------------------------------------

    if ! tem_alteracoes; then

        aviso "Não existem alterações locais para enviar."

        echo
        echo "Verificando se o GitHub possui atualizações..."
        echo

        A_FRENTE=$(git rev-list --count "origin/$BRANCH..$BRANCH")
        ATRAS=$(git rev-list --count "$BRANCH..origin/$BRANCH")

        if [ "$ATRAS" -gt 0 ]; then

            aviso "O GitHub possui $ATRAS commit(s) que você ainda não possui."

            git pull --ff-only origin "$BRANCH"

            sucesso "Código atualizado."

        else

            sucesso "Sua cópia já está atualizada."

        fi

        exit 0
    fi

    mostrar_status

    # --------------------------------------------------------
    # Solicita mensagem
    # --------------------------------------------------------

    echo "Digite a mensagem do commit."
    echo

    read -rp "Mensagem: " COMMIT_MSG

    if [ -z "$COMMIT_MSG" ]; then
        erro "A mensagem do commit não pode ser vazia."
    fi

    # --------------------------------------------------------
    # Verifica se GitHub possui commits novos
    # --------------------------------------------------------

    ATRAS=$(git rev-list --count "$BRANCH..origin/$BRANCH")

    if [ "$ATRAS" -gt 0 ]; then

        echo
        aviso "O GitHub possui $ATRAS commit(s) que ainda não estão locais."
        echo

        echo "Antes de fazer o push, precisamos atualizar sua cópia."
        echo

        erro "Execute primeiro:

    ./git_sync.sh

ou, se tiver certeza do que está fazendo:

    ./git_sync.sh --stash"

    fi

    # --------------------------------------------------------
    # Git add
    # --------------------------------------------------------

    echo
    info "Adicionando alterações..."

    git add .

    # --------------------------------------------------------
    # Mostra o que será commitado
    # --------------------------------------------------------

    echo
    echo "Arquivos que serão incluídos:"
    echo

    git status --short

    # --------------------------------------------------------
    # Commit
    # --------------------------------------------------------

    echo
    info "Criando commit..."

    git commit -m "$COMMIT_MSG"

    # --------------------------------------------------------
    # Push
    # --------------------------------------------------------

    echo
    info "Enviando para o GitHub..."

    git push origin "$BRANCH"

    echo
    sucesso "Push realizado com sucesso."

    echo
    echo "Último commit:"
    git log -1 --oneline

    exit 0

fi

# ============================================================
# MODO STASH
# ============================================================

if [ "$MODO" = "stash" ]; then

    echo
    info "Modo STASH selecionado."

    # --------------------------------------------------------
    # Verifica alterações
    # --------------------------------------------------------

    if tem_alteracoes; then

        mostrar_status

        echo
        info "Guardando alterações no stash..."

        git stash push -u -m "git_sync automático"

        sucesso "Alterações guardadas no stash."

    else

        info "Não existem alterações locais."

    fi

    # --------------------------------------------------------
    # Verifica commits locais
    # --------------------------------------------------------

    COMMITS_A_FRENTE=$(git rev-list --count "origin/$BRANCH..$BRANCH")

    if [ "$COMMITS_A_FRENTE" -gt 0 ]; then

        aviso "Existem $COMMITS_A_FRENTE commit(s) locais que ainda não estão no GitHub."

        echo
        echo "Não vou descartá-los."

        echo
        echo "Para enviá-los:"
        echo
        echo "    git push origin $BRANCH"

        exit 1

    fi

    # --------------------------------------------------------
    # Atualiza
    # --------------------------------------------------------

    COMMITS_ATRAS=$(git rev-list --count "$BRANCH..origin/$BRANCH")

    if [ "$COMMITS_ATRAS" -gt 0 ]; then

        echo
        info "Atualizando código a partir do GitHub..."

        git pull --ff-only origin "$BRANCH"

        sucesso "Código atualizado."

    else

        sucesso "Código já está atualizado."

    fi

    echo
    echo "As alterações anteriores estão no stash."

    echo
    echo "Para visualizar:"
    echo
    echo "    git stash list"

    echo
    echo "Para recuperar:"
    echo
    echo "    git stash pop"

    exit 0

fi

# ============================================================
# MODO FORCE
# ============================================================

if [ "$MODO" = "force" ]; then

    echo
    aviso "MODO FORCE"
    echo

    echo "Este procedimento irá:"
    echo
    echo "  1. DESCARTAR alterações não commitadas."
    echo "  2. DESCARTAR alterações no staging."
    echo "  3. REMOVER arquivos não rastreados."
    echo "  4. DESCARTAR commits locais que não estejam no GitHub."
    echo "  5. Deixar a branch exatamente igual a:"
    echo
    echo "       origin/$BRANCH"
    echo

    if tem_alteracoes; then
        mostrar_status
    fi

    read -rp "Digite SINCRONIZAR para continuar: " CONFIRMACAO

    if [ "$CONFIRMACAO" != "SINCRONIZAR" ]; then

        echo
        echo "Operação cancelada."

        exit 0

    fi

    # --------------------------------------------------------
    # Reset
    # --------------------------------------------------------

    echo
    info "Descartando alterações locais..."

    git reset --hard "origin/$BRANCH"

    # --------------------------------------------------------
    # Remove arquivos não rastreados
    # --------------------------------------------------------

    echo
    info "Removendo arquivos não rastreados..."

    git clean -fd

    sucesso "Cópia local sincronizada."

    exit 0

fi

# ============================================================
# MODO SAFE
# ============================================================

if [ "$MODO" = "safe" ]; then

    echo
    info "Modo seguro."

    # --------------------------------------------------------
    # Verifica alterações locais
    # --------------------------------------------------------

    if tem_alteracoes; then

        mostrar_status

        echo
        aviso "Não vou sobrescrever suas alterações locais."
        echo
        echo "Você pode executar:"
        echo
        echo "  1) Enviar para o GitHub:"
        echo
        echo "       ./git_sync.sh --push"
        echo
        echo "  2) Guardar temporariamente:"
        echo
        echo "       ./git_sync.sh --stash"
        echo
        echo "  3) DESCARTAR tudo:"
        echo
        echo "       ./git_sync.sh --force"
        echo

        exit 1

    fi

    # --------------------------------------------------------
    # Verifica commits locais
    # --------------------------------------------------------

    COMMITS_A_FRENTE=$(git rev-list --count "origin/$BRANCH..$BRANCH")

    if [ "$COMMITS_A_FRENTE" -gt 0 ]; then

        echo
        aviso "Existem $COMMITS_A_FRENTE commit(s) locais que ainda não foram enviados ao GitHub."

        echo
        echo "Para enviar:"
        echo
        echo "    git push origin $BRANCH"
        echo

        exit 1

    fi

    # --------------------------------------------------------
    # Verifica commits no GitHub
    # --------------------------------------------------------

    COMMITS_ATRAS=$(git rev-list --count "$BRANCH..origin/$BRANCH")

    if [ "$COMMITS_ATRAS" -gt 0 ]; then

        echo
        info "O GitHub possui $COMMITS_ATRAS commit(s) mais recentes."

        echo
        info "Atualizando..."

        git pull --ff-only origin "$BRANCH"

        sucesso "Código atualizado."

    else

        sucesso "Sua cópia já está sincronizada com o GitHub."

    fi

fi

# ============================================================
# VALIDAÇÃO FINAL
# ============================================================

echo
echo "============================================================"
echo "                 VALIDAÇÃO FINAL"
echo "============================================================"
echo

git status

LOCAL_HASH=$(git rev-parse HEAD)
REMOTE_HASH=$(git rev-parse "origin/$BRANCH")

echo
echo "Commit local : $LOCAL_HASH"
echo "Commit GitHub: $REMOTE_HASH"
echo

if [ "$LOCAL_HASH" = "$REMOTE_HASH" ]; then

    echo "============================================================"
    echo -e "${GREEN}REPOSITÓRIO SINCRONIZADO${NC}"
    echo "============================================================"

    echo
    git log -1 --oneline

else

    echo "============================================================"
    echo -e "${RED}REPOSITÓRIO NÃO ESTÁ SINCRONIZADO${NC}"
    echo "============================================================"

    exit 1

fi

echo
```
