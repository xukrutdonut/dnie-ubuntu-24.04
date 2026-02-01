#!/bin/bash
# Script de instalación automática de DNIe para Ubuntu 24.04
# Solución: OpenSC en lugar de libpkcs11-dnie

set -e

echo "================================================"
echo "  Instalación DNIe en Ubuntu 24.04 con OpenSC"
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

echo "[1/4] Instalando dependencias del sistema..."
sudo apt-get update -qq
sudo apt-get install -y pcscd pcsc-tools opensc || error "Falló instalación de dependencias"
success "Dependencias instaladas (pcscd, pcsc-tools, opensc)"

echo ""
echo "[2/4] Configurando servicio pcscd..."
sudo systemctl start pcscd
sudo systemctl enable pcscd 2>/dev/null || true
success "Servicio pcscd iniciado y habilitado"

echo ""
echo "[3/4] Verificando lector de tarjetas..."
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
    echo "Verificando DNIe con OpenSC..."
    pkcs11-tool --module /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so --list-slots | head -15 || warning "No se pudo verificar con OpenSC"
    success "Verificación del lector completada"
else
    warning "Inserta el DNIe y ejecuta: pkcs11-tool --module /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so --list-slots"
fi

echo ""
echo "[4/4] Configurando Firefox..."
# Cerrar Firefox
pkill firefox 2>/dev/null || true
sleep 1

# Crear archivo de configuración con OpenSC
cat > /tmp/pkcs11.txt << 'EOF'
library=/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so
name=OpenSC
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
    success "Firefox configurado en $(echo "$perfiles" | wc -l) perfil(es) con OpenSC"
    
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
echo "3. Deberías ver 'OpenSC' en la lista"
echo ""
echo "Probar el DNIe:"
echo "→ https://valide.redsara.es/valide/"
echo "→ https://www.dnielectronico.es/PortalDNIe/"
echo ""
echo "Si tienes problemas:"
echo "  • Reinicia pcscd: sudo systemctl restart pcscd"
echo "  • Verifica el DNIe: pcsc_scan"
echo "  • Verifica OpenSC: pkcs11-tool --module /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so --list-slots"
echo "  • Cierra completamente Firefox: pkill -9 firefox"
echo ""
success "OpenSC es software libre y mantenido activamente"
warning "NOTA: Chrome NO es compatible. Usa SOLO Firefox."
echo ""
