#!/bin/bash

# --- ССЫЛКИ ---
URL_COMPOSE="https://raw.githubusercontent.com/0x800700/torrserverGluetun/refs/heads/main/docker-compose.yaml"
URL_WG_CONF="https://raw.githubusercontent.com/0x800700/torrserverGluetun/refs/heads/main/wg0.conf"
URL_ACCS_DB="https://raw.githubusercontent.com/0x800700/torrserverGluetun/refs/heads/main/accs.db"

# --- ПУТИ ---
BASE_DIR=$(pwd)
OPT_DIR="$BASE_DIR/opt"
BIN_DIR="$OPT_DIR/torrserver/bin"
DB_DIR="$OPT_DIR/torrserver/db"
WG_DIR="$OPT_DIR/gluetun"
CERT_DIR="$OPT_DIR/certs"
VER_FILE="$OPT_DIR/torrserver/version.txt"

# --- ЦВЕТА ---
GREEN='\033[0;32m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# --- ФУНКЦИИ УСТАНОВКИ (ТОЛЬКО ДЛЯ ПЕРВОГО ЗАПУСКА) ---

install_torrserver_bin() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)  BIN_SUFFIX="amd64" ;;
        aarch64) BIN_SUFFIX="arm64" ;;
        *) echo -e "${RED}Ошибка: Архитектура $ARCH не поддерживается.${NC}"; exit 1 ;;
    esac

    echo -e "${PURPLE}Загрузка актуальной версии TorrServer...${NC}"
    LATEST_TAG=$(curl -s https://api.github.com/repos/YouROK/TorrServer/releases/latest | grep -oP '"tag_name": "\K[^"]+')
    
    mkdir -p "$BIN_DIR"
    curl -L "https://github.com/YouROK/TorrServer/releases/download/$LATEST_TAG/TorrServer-linux-$BIN_SUFFIX" -o "$BIN_DIR/TorrServer"
    chmod +x "$BIN_DIR/TorrServer"
    echo "$LATEST_TAG" > "$VER_FILE"
}

setup_vpn_initial() {
    # Эта функция используется при первом деплое — без кнопки "Назад"
    echo -e "\n${PURPLE}НАСТРОЙКА VPN (Cloudflare Warp):${NC}"
    mkdir -p "$WG_DIR"
    curl -sL "$URL_WG_CONF" -o "$WG_DIR/wg0.conf"
    while true; do
        read -p "Введите PrivateKey: " WG_KEY
        if [[ $WG_KEY =~ ^[A-Za-z0-9+/]{42,43}=$ ]]; then
            sed -i "s|PrivateKey =.*|PrivateKey = $WG_KEY|g" "$WG_DIR/wg0.conf"
            break
        else
            echo -e "${RED}Неверный формат ключа. Пример: CCaO3qmx...QVi0w=${NC}"
        fi
    done
}

create_admin_initial() {
    mkdir -p "$DB_DIR"
    curl -sL "$URL_ACCS_DB" -o "$DB_DIR/accs.db"
    echo -e "\n${PURPLE}СОЗДАНИЕ АДМИНИСТРАТОРА:${NC}"
    read -p "Введите Логин (по умолчанию admin): " TS_U; TS_U=${TS_U:-admin}
    read -p "Введите Пароль (по умолчанию admin): " TS_P; TS_P=${TS_P:-admin}
    
    if command -v jq &> /dev/null; then
        echo "{}" | jq --arg u "$TS_U" --arg p "$TS_P" '{($u): $p}' > "$DB_DIR/accs.db"
    else
        echo -e "{\"admin\": \"admin\"}" > "$DB_DIR/accs.db"
    fi
}

# --- ФУНКЦИИ ОБСЛУЖИВАНИЯ (ДЛЯ МЕНЮ) ---

update_logic() {
    echo -e "${PURPLE}Проверка обновлений...${NC}"
    LATEST_TAG=$(curl -s https://api.github.com/repos/YouROK/TorrServer/releases/latest | grep -oP '"tag_name": "\K[^"]+')
    LOCAL_VER=$(cat "$VER_FILE" 2>/dev/null)

    if [ "$LATEST_TAG" == "$LOCAL_VER" ]; then
        echo -e "${GREEN}У вас установлена последняя версия ($LOCAL_VER).${NC}"
    else
        echo -e "${CYAN}Обновление: $LOCAL_VER -> $LATEST_TAG...${NC}"
        docker compose stop torrserver
        install_torrserver_bin
        docker compose up -d torrserver
    fi
}

manage_users_menu() {
    while true; do
        echo -e "\n${PURPLE}УПРАВЛЕНИЕ ДОСТУПОМ:${NC}"
        echo -e " ${BOLD}1)${NC} Сбросить/Изменить админа (удалит остальных)"
        echo -e " ${BOLD}2)${NC} Инструкция по ручному добавлению пользователей"
        echo -e " ${BOLD}0)${NC} Назад"
        read -p "Выбор: " user_opt
        case $user_opt in
            1) create_admin_initial; docker compose restart torrserver; break ;;
            2) echo -e "\n${CYAN}Инструкция: https://github.com/0x800700/torrserverGluetun/blob/main/TorrServer_Authentication_accs.db.md${NC}"
               echo -e "Редактировать: ${BOLD}nano ./opt/torrserver/db/accs.db${NC}"
               read -p "Нажмите Enter..." ;;
            0) break ;;
        esac
    done
}

manage_vpn_menu() {
    while true; do
        echo -e "\n${PURPLE}ОБНОВЛЕНИЕ КЛЮЧА VPN:${NC}"
        echo -e " ${BOLD}1)${NC} Ввести новый PrivateKey"
        echo -e " ${BOLD}0)${NC} Назад"
        read -p "Выбор: " vpn_opt
        case $vpn_opt in
            1) setup_vpn_initial; docker compose restart gluetun; break ;;
            0) break ;;
        esac
    done
}

show_final_report() {
    sleep 3
    echo -e "\n\n\n"
    echo -e "\n${BOLD}${GREEN}=== ИНФРАСТРУКТУРА ГОТОВА К РАБОТЕ ===${NC}"
    echo -e "${CYAN}Место установки:${NC} $BASE_DIR"
    echo -e "\n${BOLD}Структура проекта:${NC}"
    echo -e " ${BOLD}./${NC} (Корень проекта)"
    echo -e " ├── ${PURPLE}docker-compose.yaml${NC}   — управление контейнерами"
    echo -e " └── ${PURPLE}opt/${NC}                  — данные и конфиги"
    echo -e "     ├── ${CYAN}gluetun/${NC}          — VPN надстройка"
    echo -e "     │   └── ${GREEN}wg0.conf${NC}     — ваш PrivateKey"
    echo -e "     ├── ${CYAN}torrserver/${NC}       — медиа-сервер"
    echo -e "     │   ├── ${GREEN}bin/${NC}         — исполняемый файл"
    echo -e "     │   └── ${GREEN}db/${NC}          — база и пользователи"
    echo -e "     │       └── ${BOLD}accs.db${NC}    — логины/пароли"
    echo -e "     └── ${CYAN}certs/${NC}            — SSL сертификаты"
    
    echo -e "\n${BOLD}Быстрые ссылки:${NC}"
    echo -e " • Web-интерфейс:   ${GREEN}http://ваш_ip:8090${NC}"
    echo -e " • Логи VPN:        ${CYAN}docker logs -f gluetun${NC}"
    echo -e "------------------------------------------------------"
}

# --- СТАРТ ---

if [ ! -f "$VER_FILE" ]; then
    clear
    echo -e "${BOLD}${PURPLE}TorrServer + Gluetun VPN: ПЕРВИЧНАЯ УСТАНОВКА${NC}"
    mkdir -p "$CERT_DIR" "$WG_DIR" "$DB_DIR" "$BIN_DIR"
    curl -sL https://curl.se/ca/cacert.pem -o "$CERT_DIR/ca-certificates.crt"
    curl -sL "$URL_COMPOSE" -o "$BASE_DIR/docker-compose.yaml"
    
    install_torrserver_bin
    setup_vpn_initial
    create_admin_initial
    
    echo -e "\n${GREEN}Запуск контейнеров...${NC}"
    docker compose up -d
    show_final_report
else
    while true; do
        echo -e "\n${BOLD}${PURPLE}--- МЕНЮ УПРАВЛЕНИЯ ---${NC}"
        echo -e " ${BOLD}1)${NC} Проверить обновления TorrServer"
        echo -e " ${BOLD}2)${NC} Настройка доступа (accs.db)"
        echo -e " ${BOLD}3)${NC} Обновить ключ VPN (wg0.conf)"
        echo -e " ${BOLD}4)${NC} Перезапустить все контейнеры"
        echo -e " ${BOLD}5)${NC} ${RED}Выход${NC}"
        read -p "Пункт: " opt
        case $opt in
            1) update_logic ;;
            2) manage_users_menu ;;
            3) manage_vpn_menu ;;
            4) docker compose restart ;;
            5) exit 0 ;;
        esac
    done
fi