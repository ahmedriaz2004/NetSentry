#!/bin/bash

# Colours
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

trap ctrl_c INT

# Variables Globales
workspace_path=""
project_name=""
main_dir="NetSentry_Projects" # Carpeta madre
user_ip=""
user_netmask=""

# Function to handle interruption
function ctrl_c() {
    echo -e "\n\n${yellowColour}[*]${endColour}${grayColour} Terminando la ejecución y restaurando la terminal...\n${endColour}"
    tput cnorm
    # Limpiar archivos temporales SOLAMENTE (mantenemos reportes)
    if [ -n "$workspace_path" ]; then
        rm -f "${workspace_path}/mlr_temp" "${workspace_path}/temp_ports" 2>/dev/null
    fi
    exit 1
}

# Function to generate the banner
function banner() {
    clear
    echo -e "\n${redColour}  _   _      _   ____             _                  ${endColour}"
    echo -e "${redColour} | \ | | ___| |_/ ___|  ___ _ __ | |_ _ __ _   _     ${endColour}"
    echo -e "${redColour} |  \| |/ _ \ __\___ \ / _ \ '_ \| __| '__| | | |    ${endColour}"
    echo -e "${redColour} | |\  |  __/ |_ ___) |  __/ | | | |_| |  | |_| |    ${endColour}"
    echo -e "${redColour} |_| \_|\___|\__|____/ \___|_| |_|\__|_|   \__, |    ${endColour}"
    echo -e "${redColour}                                           |___/     ${endColour}"
    
    echo -e "\n${blueColour} :: NetSentry v2.0 :: ${grayColour} Workspace Edition ${endColour}"
    echo -e "${yellowColour} By Daniel Castellano (Github: CCDani)${endColour}\n"
}

# --- GESTIÓN DE WORKSPACES ---
function workspace_manager() {
    if [ ! -d "$main_dir" ]; then
        mkdir "$main_dir"
    fi

    echo -e "${purpleColour}_______________________________________________________________________${endColour}\n"
    echo -e "${yellowColour}GESTIÓN DE PROYECTO${endColour}\n"
    echo -e "${purpleColour}[${endColour}1${purpleColour}]${endColour} ${greenColour}Crear NUEVA Auditoría${endColour}"
    echo -e "${purpleColour}[${endColour}2${purpleColour}]${endColour} ${greenColour}Cargar Auditoría EXISTENTE${endColour}"
    echo -e "${purpleColour}_______________________________________________________________________${endColour}\n"

    while true; do
        echo -ne "\n${grayColour}Selecciona una opción: ${endColour}"
        read ws_opt

        case $ws_opt in
            1)
                echo -ne "\n${yellowColour}Introduce el nombre de la auditoría (sin espacios): ${endColour}"
                read project_name
                # Sanitización básica
                project_name=$(echo "$project_name" | sed 's/[^a-zA-Z0-9_]//g')
                
                if [ -z "$project_name" ]; then
                    echo -e "\n${redColour}[!] Nombre inválido.${endColour}"
                    continue
                fi

                workspace_path="${main_dir}/${project_name}"

                if [ -d "$workspace_path" ]; then
                    echo -e "\n${redColour}[!] Ya existe una carpeta con ese nombre. Cargándola...${endColour}"
                else
                    mkdir -p "$workspace_path"
                    echo -e "\n${greenColour}[+] Proyecto '$project_name' creado exitosamente.${endColour}"
                fi
                break
                ;;
            2)
                if [ -z "$(ls -A $main_dir 2>/dev/null)" ]; then
                    echo -e "\n${redColour}[!] No hay auditorías previas creadas.${endColour}"
                    continue
                fi

                echo -e "\n${blueColour}Auditorías disponibles:${endColour}"
                select dir in $(ls -d $main_dir/*/ 2>/dev/null | xargs -n 1 basename); do
                    if [ -n "$dir" ]; then
                        project_name=$dir
                        workspace_path="${main_dir}/${project_name}"
                        echo -e "\n${greenColour}[+] Proyecto '$project_name' cargado.${endColour}"
                        break
                    else
                        echo -e "${redColour}[!] Selección inválida.${endColour}"
                    fi
                done
                break
                ;;
            *)
                echo -e "\n${redColour}[!] Opción inválida.${endColour}"
                ;;
        esac
    done
    
    echo -e "${grayColour}Ruta de trabajo actual: ${endColour}${blueColour}$workspace_path${endColour}"
}

# Initial options
function main_options() {
    echo -e "\n${purpleColour}_______________________________________________________________________${endColour}\n"
    echo -e "\n${yellowColour}AUDITORÍA: ${project_name}${endColour}\n"
    echo -e "${purpleColour}[${endColour}1${purpleColour}]${endColour} ${greenColour}Descubrimiento de Hosts (Verbose + XML)${endColour}\n"
    echo -e "${purpleColour}[${endColour}2${purpleColour}]${endColour} ${greenColour}Enumeración y CVEs (Usa target_ips.txt del proyecto)${endColour}\n"
    echo -e "\n${purpleColour}_______________________________________________________________________${endColour}\n"
}

function validate_interface() {
    local interface=$1
    local interfaces=$(ip link show | grep -oP '\d+: \K[^:]+')
    for intf in $interfaces; do
        if [[ $intf == $interface ]]; then return 0; fi
    done
    return 1
}

function validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then return 0; else return 1; fi
}

function validate_netmask() {
    local mask=$1
    if [[ $mask =~ ^(255\.255\.255\.(255|254|252|248|240|224|192|128|0)|255\.255\.(255|254|252|248|240|224|192|128|0)\.0|255\.(255|254|252|248|240|224|192|128|0)\.0\.0|(255|254|252|248|240|224|192|128|0)\.0\.0\.0)$ ]]; then return 0; else return 1; fi
}

# Función para obtener info de red
function get_network_info() {
    echo -e "\n${greenColour}_______________________________________________________________________${endColour}\n"
    echo -e "\n${purpleColour}[${endColour}1${purpleColour}]${endColour} ${yellowColour}Descubrimiento en la red actual (Local Interface)${endColour}\n"
    echo -e "${purpleColour}[${endColour}2${purpleColour}]${endColour} ${yellowColour}Descubrimiento en red personalizada (Manual IP/Mask)${endColour}\n"
    echo -e "\n${greenColour}_______________________________________________________________________${endColour}\n"
    
    while true; do
        echo -ne "\n${grayColour}Selecciona una opción: ${endColour}"
        read user_input
        case $user_input in
            1)
                while true; do
                    echo -ne "\n${yellowColour}Introduce tu interfaz de red (ej. eth0, ens33): ${endColour}" 
                    read user_network_interface
                    if ! validate_interface "$user_network_interface"; then
                        echo -e "\n${redColour}[!] Interfaz inválida.${endColour}"; continue
                    fi
                    user_ip=$(ip -o -4 addr show "$user_network_interface" | awk '{split($4, array, "/"); print array[1]}')
                    cidr=$(ip -o -4 addr show "$user_network_interface" | awk '{split($4, array, "/"); print array[2]}')
                    if [ -z "$user_ip" ] || [ -z "$cidr" ]; then
                         echo -e "\n${redColour}[!] Error obteniendo IP/CIDR.${endColour}"; exit 1
                    fi
                    user_netmask=$(ipcalc "$user_ip/$cidr" | grep "Netmask" | awk '{print $2}')
                    break
                done
                break
                ;;
            2)
                while true; do
                    echo -ne "\n${yellowColour}IP (ej. 192.168.1.10): ${endColour}"; read user_ip
                    if ! validate_ip "$user_ip"; then echo -e "${redColour}[!] IP Inválida${endColour}"; continue; fi
                    break
                done
                while true; do
                    echo -ne "\n${yellowColour}Máscara (ej. 255.255.255.0): ${endColour}"; read user_netmask
                    if ! validate_netmask "$user_netmask"; then echo -e "${redColour}[!] Máscara Inválida${endColour}"; continue; fi
                    break
                done
                break
                ;;
            *) echo -e "\n${redColour}[!] Opción inválida.${endColour}";;
        esac
    done
}

# Función de Descubrimiento
function auto_host_discovery() {
    get_network_info
    clear
    network_range=$(ipcalc -b $user_ip $user_netmask | grep "Network" | awk '{print $2}')
    
    echo -e "\n${purpleColour}__________________________________________________${endColour}\n"
    echo -e "\n${blueColour}Proyecto:${endColour} $project_name"
    echo -e "\n${blueColour}Rango a Escanear:${endColour} $network_range"
    echo -e "\n${purpleColour}__________________________________________________${endColour}\n"

    echo -e "\n${yellowColour}[*]${endColour}${grayColour} Iniciando escaneo de Hosts...${endColour}"
    tput civis

    # Guardamos los archivos DENTRO de la carpeta del workspace
    local discovery_base="${workspace_path}/discovery_hosts"
    
    sudo nmap -sn -v -n -PR -PS22,80,443 "$network_range" -T4 -oA "$discovery_base"
    
    tput cnorm
    
    if [ -f "${discovery_base}.gnmap" ]; then
        # Extraer IPs y guardar en target_ips.txt dentro del workspace
        grep "Up$" "${discovery_base}.gnmap" | awk '{print $2}' | sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4 > "${workspace_path}/target_ips.txt"
    else
        echo -e "\n${redColour}[!] Error: No se generó el archivo de reporte.${endColour}"
        exit 1
    fi

    target_file="${workspace_path}/target_ips.txt"
    
    if [ ! -s "$target_file" ]; then
        echo -e "\n${redColour}[!] No se descubrieron hosts activos.${endColour}\n"
        rm "$target_file"
        exit 1
    fi

    echo -e "\n${greenColour}[+]${endColour}${grayColour} Hosts activos guardados en: ${endColour}${blueColour}$target_file${endColour}"
    echo -e "\n${purpleColour}Hosts Activos Encontrados:${endColour}"
    
    # Mostrar tabla bonita
    if command -v mlr &> /dev/null; then
        echo "\"Discovered Hosts\"" > "${workspace_path}/mlr_temp"
        cat "$target_file" >> "${workspace_path}/mlr_temp"
        mlr --icsv --opprint --barred --key-color 231 --value-color 10 cat "${workspace_path}/mlr_temp"
        rm "${workspace_path}/mlr_temp"
    else
        cat "$target_file"
    fi
    
    echo -e "\n${yellowColour}Lista lista para la Opción 2.${endColour}"
}

# Función de Enumeración con VULNERS (SMART SCAN)
function service_enumeration() {
    clear
    local target_file="${workspace_path}/target_ips.txt"
    
    if [ ! -f "$target_file" ]; then
        echo -e "\n${redColour}[!] No se encontró el archivo target_ips.txt en el proyecto '$project_name'.${endColour}"
        echo -e "${grayColour}Ejecuta primero la Opción 1.${endColour}\n"
        return
    fi
    
    local host_count=$(wc -l < "$target_file")
    
    echo -e "\n${purpleColour}__________________________________________________${endColour}\n"
    echo -e "\n${blueColour}Proyecto:${endColour} $project_name"
    echo -e "\n${blueColour}Hosts a Escanear:${endColour} $host_count"
    echo -e "\n${purpleColour}__________________________________________________${endColour}\n"

    # --- FORMATO RESTAURADO ---
    echo -e "${yellowColour}SELECCIONA EL MODO DE ESCANEO:${endColour}"
    echo -e "${purpleColour}[${endColour}1${purpleColour}]${endColour} ${greenColour}SMART SCAN (Recomendado)${endColour}"
    echo -e "    ${grayColour}1. Escanea los 65535 puertos muy rápido (solo detección).${endColour}"
    echo -e "    ${grayColour}2. Analiza a fondo y busca CVEs SOLO en los puertos abiertos.${endColour}"
    echo -e "    ${grayColour}Result: Velocidad de escaneo rápido con precisión de escaneo full.${endColour}\n"

    echo -e "${purpleColour}[${endColour}2${purpleColour}]${endColour} ${redColour}TRADICIONAL (Lento)${endColour}"
    echo -e "    ${grayColour}Lanza todo contra todo de una vez. (Puede tardar horas).${endColour}"
    
    echo -ne "\n${grayColour}Opción: ${endColour}"
    read scan_mode

    local report_name="${workspace_path}/vuln_report_$(date +%Y%m%d_%H%M%S)"

    if [ "$scan_mode" == "1" ]; then
        # --- PASO 1: Descubrimiento rápido ---
        echo -e "\n${yellowColour}[Phase 1/2]${endColour}${grayColour} Identificando puertos abiertos en todos los hosts (Min-rate 2000)...${endColour}"
        tput civis
        
        local temp_ports="${workspace_path}/temp_ports"
        
        # Escaneo SYN muy rápido solo para detectar estado
        sudo nmap -p- --open -sS --min-rate 2000 -n -Pn -iL "$target_file" -oG "$temp_ports" > /dev/null
        
        tput cnorm

        # Extraer puertos únicos limpios (ej: 22,80,443)
        local ports_to_scan=$(grep -oP '\d+/open' "$temp_ports" | awk -F '/' '{print $1}' | sort -u | tr '\n' ',' | sed 's/,$//')
        
        rm "$temp_ports" 2>/dev/null

        if [ -z "$ports_to_scan" ]; then
            echo -e "\n${redColour}[!] No se encontraron puertos abiertos en el escaneo rápido.${endColour}"
            return
        fi

        echo -e "\n${greenColour}[+]${endColour} Puertos identificados para análisis profundo: ${blueColour}$ports_to_scan${endColour}"

        # --- PASO 2: Análisis de Vulnerabilidades ---
        echo -e "\n${yellowColour}[Phase 2/2]${endColour}${grayColour} Analizando versiones y CVEs en los puertos detectados...${endColour}"
        tput civis
        
        sudo nmap -vv -Pn -sV --version-intensity 5 --script vulners -p "$ports_to_scan" -T4 -O -iL "$target_file" -oA "$report_name"

    else
        # MODO TRADICIONAL
        echo -e "\n${yellowColour}[*]${endColour}${grayColour} Iniciando modo FULL tradicional (Esto tomará tiempo)...${endColour}"
        tput civis
        sudo nmap -vv -Pn -sS -sV --version-intensity 5 --script vulners -p- -T4 --min-rate 1000 -O -iL "$target_file" -oA "$report_name"
    fi
    
    tput cnorm

    echo -e "\n${greenColour}[+]${endColour}${grayColour} Auditoría completada.${endColour}"
    echo -e "${greenColour}[+]${endColour}${grayColour} Reporte XML generado: ${endColour}${blueColour}${report_name}.xml${endColour}"
    
    echo -e "\n${purpleColour}Resumen de Puertos:${endColour}"
    grep 'Ports' "${report_name}.gnmap" 2>/dev/null | awk '{printf "%s -> %s\n", $2, $6}' | sed 's/Ports: //'

    # --- MENSAJE FINAL DASHBOARD ---
    echo -e "\n${purpleColour}_______________________________________________________________________${endColour}"
    echo -e "\n${yellowColour}[TIP]${endColour} ${grayColour}Visualiza estos resultados gráficamente usando tu dashboard:${endColour}"
    echo -e "${blueColour}https://github.com/CCDani/nmap-dashboard-analyzer${endColour}\n"
}

# Main 
if [ "$(id -u)" != "0" ]; then
    echo -e "\n${redColour}[!] Se requieren privilegios de root.${endColour}\n"
    exit 1
fi

if ! command -v ipcalc &> /dev/null; then
    echo -e "\n${redColour}[!] Error: 'ipcalc' no está instalado.${endColour}\n"
    exit 1
fi

banner
workspace_manager
main_options

while true; do
    echo -ne "\n${grayColour}Selecciona una opción: ${endColour}"
    read user_input
    case $user_input in
        1)
            auto_host_discovery
            main_options
            ;;
        2)
            service_enumeration
            exit 0
            ;;
        *)
            echo -e "\n${redColour}[!] Opción inválida.${endColour}"
            ;;
    esac
done

tput cnorm
exit 0S