#!/bin/bash
# Script de instalación automática de DNIe para Ubuntu 24.04
# Fuentes:
# - https://2tazasdelinux.blogspot.com/2025/04/hacer-funcionar-dnie-en-ubuntu.html
# - https://www.asanzdiego.com/2024/08/configurar-un-lector-de-dni-electronico-en-firefox-con-autofirma-en-ubuntu-version-2024.html

set -e

echo "================================================"
echo "  Instalación DNIe en Ubuntu 24.04"
echo "================================================"
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para mostrar errores
error() {
    echo -e "${RED}✗ ERROR: $1${NC}" >&2
    exit 1
}

# Función para mostrar éxitos
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Función para mostrar advertencias
warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Verificar que estamos en Ubuntu 24.04
if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
    warning "Este script está diseñado para Ubuntu. Puede que funcione en otras distribuciones."
fi

echo "[1/6] Instalando dependencias del sistema..."
sudo apt-get update -qq
sudo apt-get install -y pcscd pcsc-tools libccid libnss3-tools pinentry-gtk2 || error "Falló instalación de dependencias"
success "Dependencias instaladas"

echo ""
echo "[2/6] Creando enlace simbólico para libassuan..."
if [ -L /lib/x86_64-linux-gnu/libassuan.so.0 ]; then
    warning "El enlace simbólico ya existe"
else
    sudo ln -sf /lib/x86_64-linux-gnu/libassuan.so.9 /lib/x86_64-linux-gnu/libassuan.so.0
    success "Enlace simbólico creado"
fi

# Verificar enlace
ls -la /lib/x86_64-linux-gnu/libassuan.so* | grep "libassuan.so.0"

echo ""
echo "[3/6] Descargando libpkcs11-dnie..."
cd /tmp
if [ ! -f libpkcs11-dnie_1.6.8_amd64.deb ]; then
    wget -q --show-progress https://www.dnielectronico.es/descargas/CSP_para_Sistemas_Unix/libpkcs11-dnie_1.6.8_amd64.deb || error "Falló descarga del paquete"
    success "Paquete descargado"
else
    warning "Paquete ya descargado"
fi

echo ""
echo "[4/6] Instalando libpkcs11-dnie..."
# Cerrar Firefox si está abierto
pkill firefox 2>/dev/null || true
sleep 1

# Instalar forzando dependencias
sudo dpkg -i --force-depends libpkcs11-dnie_1.6.8_amd64.deb 2>&1 | grep -v "^$" || true

# Verificar instalación
if dpkg -l | grep -q libpkcs11-dnie; then
    success "libpkcs11-dnie instalado correctamente"
else
    error "Falló instalación de libpkcs11-dnie"
fi

echo ""
echo "[5/6] Verificando lector de tarjetas..."
# Iniciar servicio pcscd
sudo systemctl start pcscd
sudo systemctl enable pcscd 2>/dev/null || true

# Buscar lectores
lectores=$(lsusb | grep -i "card\|reader\|smart" || true)
if [ -n "$lectores" ]; then
    success "Lector USB detectado:"
    echo "$lectores"
else
    warning "No se detectó ningún lector USB. Asegúrate de que esté conectado."
fi

echo ""
echo "¿Tienes el DNIe insertado en el lector? (s/n)"
read -r respuesta
if [[ "$respuesta" =~ ^[Ss]$ ]]; then
    echo "Verificando DNIe..."
    timeout 3s pcsc_scan 2>&1 | head -20 || true
    success "Verificación del lector completada"
else
    warning "Inserta el DNIe y ejecuta: pcsc_scan"
fi

echo ""
echo "[6/6] Configurando Firefox..."
# Cerrar Firefox
pkill firefox 2>/dev/null || true
sleep 1

# Crear archivo de configuración
cat > /tmp/pkcs11.txt << 'EOF'
library=/usr/lib/libpkcs11-dnie.so
name=DNI-e
EOF

# Buscar perfiles de Firefox
perfiles=$(ls ~/.mozilla/firefox/ 2>/dev/null | grep .default || true)

if [ -z "$perfiles" ]; then
    warning "No se encontraron perfiles de Firefox."
    warning "Abre Firefox primero para crear un perfil, luego ejecuta:"
    echo "    for perfil in \$(ls ~/.mozilla/firefox/ | grep .default); do"
    echo "        cp /tmp/pkcs11.txt ~/.mozilla/firefox/\$perfil/pkcs11.txt"
    echo "    done"
else
    for perfil in $perfiles; do
        echo "  → Configurando perfil: $perfil"
        cp /tmp/pkcs11.txt "$HOME/.mozilla/firefox/$perfil/pkcs11.txt"
    done
    success "Firefox configurado en $(echo "$perfiles" | wc -l) perfil(es)"
    
    # Mostrar archivos creados
    echo ""
    echo "Archivos de configuración creados:"
    find "$HOME/.mozilla/firefox" -name "pkcs11.txt" 2>/dev/null
fi

echo ""
echo "================================================"
echo -e "${GREEN}✓ Instalación completada${NC}"
echo "================================================"
echo ""
echo "Próximos pasos:"
echo ""
echo "1. Abre Firefox"
echo "2. Ve a about:preferences#privacy → Dispositivos de seguridad"
echo "3. Deberías ver 'DNI-e' en la lista"
echo ""
echo "Probar el DNIe:"
echo "→ https://www.sede.fnmt.gob.es/certificados/persona-fisica/verificar-estado/solicitar-verificacion"
echo ""
echo "Si tienes problemas:"
echo "  • Reinicia pcscd: sudo systemctl restart pcscd"
echo "  • Verifica el DNIe: pcsc_scan"
echo "  • Cierra completamente Firefox: pkill -9 firefox"
echo ""
warning "NOTA: Google Chrome NO funciona por incompatibilidad de libassuan."
warning "      Usa SOLO Firefox para el DNIe en Ubuntu 24.04."
echo ""
