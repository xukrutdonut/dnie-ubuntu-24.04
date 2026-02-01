# Resolución de Problemas - DNIe en Ubuntu 24.04

## 🔍 Diagnóstico paso a paso

### 1. Verificar que el lector está conectado

```bash
lsusb | grep -i "card\|reader\|smart"
```

**Salida esperada:**
```
Bus 003 Device 019: ID 14cd:1212 Super Top microSD card reader
```

❌ **Si no aparece nada:**
- Verifica que el lector esté conectado
- Prueba otro puerto USB
- Reinicia el ordenador

---

### 2. Verificar servicio pcscd

```bash
sudo systemctl status pcscd
```

**Salida esperada:**
```
● pcscd.service - PC/SC Smart Card Daemon
     Loaded: loaded
     Active: active (running)
```

❌ **Si no está activo:**
```bash
sudo systemctl start pcscd
sudo systemctl enable pcscd
```

---

### 3. Verificar que el DNIe se detecta

```bash
pcsc_scan
```

**Con DNIe insertado:**
```
Card state: Card inserted
ATR: 3B 7F 00 00 00 00 6A 44 4E 49 65 00 ...
```

**Sin DNIe:**
```
Card state: Card removed
```

❌ **Si dice "Reader not found":**
```bash
sudo apt-get install --reinstall pcscd libccid pcsc-tools
sudo systemctl restart pcscd
```

---

### 4. Verificar instalación de libpkcs11-dnie

```bash
dpkg -l | grep libpkcs11-dnie
```

**Salida esperada:**
```
ii  libpkcs11-dnie  1.6.8  amd64  SmartCard library with support for dnie card
```

❌ **Si no está instalado:**
```bash
cd /tmp
wget https://www.dnielectronico.es/descargas/CSP_para_Sistemas_Unix/libpkcs11-dnie_1.6.8_amd64.deb
sudo dpkg -i --force-depends libpkcs11-dnie_1.6.8_amd64.deb
```

---

### 5. Verificar enlace simbólico de libassuan

```bash
ls -la /lib/x86_64-linux-gnu/libassuan.so*
```

**Salida esperada:**
```
lrwxrwxrwx ... libassuan.so.0 -> /lib/x86_64-linux-gnu/libassuan.so.9
lrwxrwxrwx ... libassuan.so.9 -> libassuan.so.9.0.2
```

❌ **Si libassuan.so.0 no existe:**
```bash
sudo ln -sf /lib/x86_64-linux-gnu/libassuan.so.9 /lib/x86_64-linux-gnu/libassuan.so.0
```

---

### 6. Verificar configuración de Firefox

```bash
find ~/.mozilla/firefox -name "pkcs11.txt"
```

**Salida esperada:**
```
/home/usuario/.mozilla/firefox/xxxxx.default-release/pkcs11.txt
```

**Contenido del archivo:**
```bash
cat ~/.mozilla/firefox/*.default-release/pkcs11.txt
```

Debe contener:
```
library=/usr/lib/libpkcs11-dnie.so
name=DNI-e
```

❌ **Si no existe:**
```bash
pkill firefox
cat > /tmp/pkcs11.txt << 'EOF'
library=/usr/lib/libpkcs11-dnie.so
name=DNI-e
EOF

for perfil in $(ls ~/.mozilla/firefox/ | grep .default); do
    cp /tmp/pkcs11.txt ~/.mozilla/firefox/$perfil/pkcs11.txt
done
```

---

### 7. Verificar dispositivos de seguridad en Firefox

1. Abre Firefox
2. Escribe en la barra: `about:preferences#privacy`
3. Busca **"Dispositivos de seguridad"**
4. Deberías ver **"DNI-e"** en la lista

❌ **Si no aparece:**
- Cierra Firefox completamente: `pkill -9 firefox`
- Verifica que el archivo `pkcs11.txt` existe
- Abre Firefox de nuevo

---

## 🐛 Errores comunes

### Error: "LIBASSUAN_1.0 not found"

**Descripción:**
```
/lib/x86_64-linux-gnu/libassuan.so.0: version `LIBASSUAN_1.0' not found
```

**Causa:** El enlace simbólico no está creado o apunta al lugar incorrecto.

**Solución:**
```bash
sudo ln -sf /lib/x86_64-linux-gnu/libassuan.so.9 /lib/x86_64-linux-gnu/libassuan.so.0
```

---

### Error: "No se puede acceder al dispositivo"

**Causa:** Permisos insuficientes para acceder al lector.

**Solución:**
```bash
# Añadir usuario al grupo scard
sudo usermod -aG scard $USER

# Reiniciar sesión (cerrar sesión y volver a entrar)
```

Verificar grupos:
```bash
groups
```

---

### Error: "PIN incorrecto" repetidamente

**Causa:** El PIN del DNIe es incorrecto.

**Importante:**
- El PIN se configura en comisaría al obtener el DNI
- Son **4 dígitos** por defecto
- Tras **3 intentos fallidos** se bloquea

**Si se bloquea:**
1. Ve a comisaría con tu DNI
2. Solicita el **código PUK**
3. Desbloquea el DNIe

---

### Error: Firefox no detecta el módulo

**Síntomas:** En "Dispositivos de seguridad" no aparece "DNI-e"

**Solución:**
```bash
# Cerrar Firefox completamente
pkill -9 firefox

# Eliminar caché de módulos
rm -rf ~/.mozilla/firefox/*.default*/pkcs11.txt

# Reinstalar configuración
cat > /tmp/pkcs11.txt << 'EOF'
library=/usr/lib/libpkcs11-dnie.so
name=DNI-e
EOF

for perfil in $(ls ~/.mozilla/firefox/ | grep .default); do
    cp /tmp/pkcs11.txt ~/.mozilla/firefox/$perfil/pkcs11.txt
done

# Abrir Firefox de nuevo
firefox &
```

---

### Error: Múltiples perfiles de Firefox

**Síntomas:** AutoFirma no funciona o configuración inconsistente

**Ver perfiles:**
```bash
firefox -P
```

O editar:
```bash
vim ~/.mozilla/firefox/profiles.ini
```

**Solución:** Usar solo el perfil `default-release`. Eliminar perfiles no usados.

---

### Error: "Error en la comunicación con el módulo de seguridad"

**Causa:** El módulo no carga correctamente en Firefox.

**Solución:**
```bash
# Verificar que la librería existe
ls -l /usr/lib/libpkcs11-dnie.so

# Verificar que tiene permisos de lectura
sudo chmod 644 /usr/lib/libpkcs11-dnie.so

# Reinstalar si es necesario
sudo apt-get install --reinstall libpkcs11-dnie
```

---

## 🔬 Pruebas avanzadas

### Probar la librería directamente con OpenSC

```bash
# Instalar OpenSC
sudo apt-get install opensc

# Listar lectores
opensc-tool --list-readers

# Listar slots
pkcs11-tool --module /usr/lib/libpkcs11-dnie.so --list-slots

# Listar objetos (con DNIe insertado)
pkcs11-tool --module /usr/lib/libpkcs11-dnie.so --list-objects
```

---

### Logs del sistema

```bash
# Ver logs de pcscd
journalctl -u pcscd -f

# Ver logs del sistema relacionados con USB
dmesg | grep -i "usb\|card"

# Ver logs de Firefox (ejecutar Firefox desde terminal)
firefox 2>&1 | grep -i "security\|pkcs11\|dnie"
```

---

## 📊 Checklist completo

Antes de pedir ayuda, verifica:

- [ ] El lector USB está conectado (`lsusb`)
- [ ] El servicio pcscd está activo (`systemctl status pcscd`)
- [ ] El DNIe se detecta (`pcsc_scan`)
- [ ] libpkcs11-dnie está instalado (`dpkg -l | grep libpkcs11`)
- [ ] El enlace simbólico existe (`ls -la /lib/x86_64-linux-gnu/libassuan.so.0`)
- [ ] El archivo pkcs11.txt existe (`find ~/.mozilla/firefox -name pkcs11.txt`)
- [ ] Firefox está completamente cerrado antes de probar
- [ ] El PIN del DNIe es correcto (4 dígitos)
- [ ] No estás usando Chrome (no funciona en Ubuntu 24.04)

---

## 🆘 Obtener ayuda

Si nada funciona, proporciona esta información:

```bash
# Información del sistema
uname -a
lsb_release -a

# Estado del lector
lsusb | grep -i "card\|reader\|smart"
pcsc_scan | head -20

# Estado de paquetes
dpkg -l | grep -E "libpkcs11-dnie|pcscd|libccid"

# Estado de libassuan
ls -la /lib/x86_64-linux-gnu/libassuan.so*

# Configuración Firefox
find ~/.mozilla/firefox -name "pkcs11.txt" -exec cat {} \;

# Logs
journalctl -u pcscd --no-pager | tail -50
```

Pega toda la salida al pedir ayuda.

---

## 📚 Recursos adicionales

- [DNI Electrónico - Página oficial](https://www.dnielectronico.es/)
- [FNMT - Verificación](https://www.sede.fnmt.gob.es/)
- [Foro Ubuntu-es](https://www.ubuntu-es.org/)
- [GitHub - Issues](https://github.com/tu-usuario/dnie-ubuntu-24.04/issues)
