# 🪪 Configurar DNIe en Ubuntu 24.04 LTS

[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%20LTS-E95420?logo=ubuntu)](https://ubuntu.com/)
[![Firefox](https://img.shields.io/badge/Firefox-Compatible-FF7139?logo=firefox)](https://www.mozilla.org/firefox/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Guía completa para configurar el **DNI electrónico español** en **Ubuntu 24.04 LTS**, incluyendo solución al problema de `libassuan0` y configuración de Firefox.

> **⚠️ Nota importante:** Esta solución funciona **solo con Firefox**. Google Chrome no es compatible debido a incompatibilidades con `libassuan`.

## 🚀 Instalación rápida

```bash
wget -O - https://raw.githubusercontent.com/xukrutdonut/dnie-ubuntu-24.04/master/instalar-dnie.sh | bash
```

O descarga y ejecuta manualmente:

```bash
git clone https://github.com/xukrutdonut/dnie-ubuntu-24.04.git
cd dnie-ubuntu-24.04
chmod +x instalar-dnie.sh
./instalar-dnie.sh
```

## 📋 Contenido

- **[README.md](README.md)** - Esta guía (instalación paso a paso)
- **[instalar-dnie.sh](instalar-dnie.sh)** - Script de instalación automática
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Resolución de problemas detallada
- **[DEVELOPMENT.md](DEVELOPMENT.md)** - Historial del desarrollo y decisiones técnicas

## 📋 Índice

1. [Problema principal](#problema-principal)
2. [Solución implementada](#solución-implementada)
3. [Instalación paso a paso](#instalación-paso-a-paso)
4. [Verificación](#verificación)
5. [Resolución de problemas](#resolución-de-problemas)
6. [Referencias](#referencias)

---

## ⚠️ Problema principal

El paquete oficial `libpkcs11-dnie` de la Policía Nacional depende de `libassuan0`, que **ya no existe en Ubuntu 24.04**. Ubuntu 24.04 usa `libassuan9`, incompatible con el driver del DNIe.

### Error típico:
```
/lib/x86_64-linux-gnu/libassuan.so.0: version `LIBASSUAN_1.0' not found
```

---

## ✅ Solución implementada

1. **Crear enlace simbólico** de `libassuan.so.9` → `libassuan.so.0`
2. **Forzar instalación** del paquete `libpkcs11-dnie` ignorando dependencias
3. **Configurar solo Firefox** (Chrome requiere módulos NSS incompatibles)

---

## 🚀 Instalación paso a paso

### 1. Instalar dependencias del sistema

```bash
sudo apt-get update
sudo apt-get install -y pcscd pcsc-tools libccid libnss3-tools pinentry-gtk2
```

### 2. Crear enlace simbólico para libassuan

```bash
sudo ln -sf /lib/x86_64-linux-gnu/libassuan.so.9 /lib/x86_64-linux-gnu/libassuan.so.0
```

Verificar:
```bash
ls -la /lib/x86_64-linux-gnu/libassuan.so*
```

Deberías ver:
```
lrwxrwxrwx 1 root root 36 libassuan.so.0 -> /lib/x86_64-linux-gnu/libassuan.so.9
lrwxrwxrwx 1 root root 18 libassuan.so.9 -> libassuan.so.9.0.2
```

### 3. Descargar e instalar libpkcs11-dnie

```bash
cd /tmp
wget https://www.dnielectronico.es/descargas/CSP_para_Sistemas_Unix/libpkcs11-dnie_1.6.8_amd64.deb
sudo dpkg -i --force-depends libpkcs11-dnie_1.6.8_amd64.deb
```

**Importante:** Durante la instalación puede intentar abrir Firefox. Ciérralo para que la instalación continúe.

Verificar instalación:
```bash
dpkg -l | grep libpkcs11-dnie
```

### 4. Verificar lector de tarjetas

Conecta el lector USB y verifica:

```bash
lsusb | grep -i "card\|reader\|smart"
```

Inicia el servicio:
```bash
sudo systemctl start pcscd
sudo systemctl enable pcscd
```

Inserta el DNIe y prueba:
```bash
pcsc_scan
```

Deberías ver información del DNIe. Presiona `Ctrl+C` para salir.

### 5. Configurar Firefox

#### Opción A: Script automático

```bash
pkill firefox
sleep 1

# Crear archivo de configuración
cat > /tmp/pkcs11.txt << 'EOF'
library=/usr/lib/libpkcs11-dnie.so
name=DNI-e
EOF

# Instalar en todos los perfiles
for perfil in $(ls ~/.mozilla/firefox/ | grep .default); do
    cp /tmp/pkcs11.txt ~/.mozilla/firefox/$perfil/pkcs11.txt
done

# Verificar
find ~/.mozilla/firefox -name "pkcs11.txt"
```

#### Opción B: Configuración manual

1. Abre Firefox
2. Ve a **Preferencias** → **Privacidad y Seguridad**
3. Desplázate hasta **Certificados** → **Dispositivos de seguridad**
4. Clic en **Cargar**
5. Nombre del módulo: `DNI-e`
6. Ruta del archivo: `/usr/lib/libpkcs11-dnie.so`
7. Aceptar

#### Agregar certificado raíz (opcional pero recomendado)

1. En Firefox: **Preferencias** → **Privacidad y Seguridad** → **Ver certificados**
2. Pestaña **Autoridades** → **Importar**
3. Selecciona: `/usr/share/libpkcs11-dnie/ac_raiz_dnie.crt`
4. Marca todas las casillas de confianza
5. Aceptar

---

## ✅ Verificación

### Probar DNIe en Firefox

1. Inserta el DNIe en el lector
2. Abre Firefox
3. Ve a: https://www.sede.fnmt.gob.es/certificados/persona-fisica/verificar-estado/solicitar-verificacion
4. Te pedirá el **PIN del DNIe** (código que te dieron en comisaría)
5. Si funciona, verás tus datos personales

### Verificar dispositivos de seguridad

En Firefox:
- `about:preferences#privacy` → Dispositivos de seguridad
- Deberías ver **DNI-e** en la lista

---

## 🔧 Resolución de problemas

### Firefox no detecta el DNIe

```bash
# Reiniciar servicios
sudo systemctl restart pcscd

# Verificar que el DNIe está insertado
pcsc_scan

# Cerrar completamente Firefox
pkill -9 firefox

# Verificar configuración
ls ~/.mozilla/firefox/*/pkcs11.txt
```

### Error "no se puede acceder al dispositivo"

```bash
# Añadir usuario al grupo pcscd
sudo usermod -aG pcscd $USER

# Cerrar sesión y volver a entrar
```

### El lector no se detecta

```bash
# Ver lectores USB
lsusb

# Reinstalar drivers
sudo apt-get install --reinstall pcscd libccid pcsc-tools
```

### Múltiples perfiles de Firefox causan problemas

Firefox puede tener problemas con múltiples perfiles. Para ver y gestionar perfiles:

```bash
firefox -P
```

O editar directamente:
```bash
vim ~/.mozilla/firefox/profiles.ini
```

Si usas **AutoFirma**, necesitas tener **solo el perfil `default-release`**.

---

## ⚠️ Limitaciones conocidas

### Chrome/Chromium NO funciona

Google Chrome requiere configurar el módulo NSS, pero `modutil` falla por incompatibilidad de `libassuan`:

```bash
modutil -add "DNI-e" -libfile /usr/lib/libpkcs11-dnie.so -dbdir sql:$HOME/.pki/nssdb
# ERROR: version `LIBASSUAN_1.0' not found
```

**Solución:** Usar **solo Firefox** para DNIe en Ubuntu 24.04.

### AutoFirma

AutoFirma funciona con esta configuración, pero requiere:
1. Solo un perfil de Firefox (`default-release`)
2. Restaurar instalación desde AutoFirma después de configurar

---

## 📚 Referencias

- [Guía 2tazasdelinux (2025)](https://2tazasdelinux.blogspot.com/2025/04/hacer-funcionar-dnie-en-ubuntu.html)
- [Guía asanzdiego (2024)](https://www.asanzdiego.com/2024/08/configurar-un-lector-de-dni-electronico-en-firefox-con-autofirma-en-ubuntu-version-2024.html)
- [Página oficial DNIe](https://www.dnielectronico.es/)
- [FNMT - Verificación de certificados](https://www.sede.fnmt.gob.es/)

---

## 🛠️ Script de instalación automática

Ver [`instalar-dnie.sh`](./instalar-dnie.sh) para instalación automatizada.

---

## 📝 Notas adicionales

### Lectores probados que funcionan

- **SCM SCR 3310** (lector oficial del Ministerio)
- **Generic Smart Card Reader (Realtek)**
- **HP USB Smartcard CCID Keyboard**
- **Trust Primo Smart Card Reader 23890**

### Seguridad

- El PIN del DNIe se configura en comisaría al obtener el DNI
- Por defecto son **4 dígitos**
- Tras **3 intentos fallidos** se bloquea (necesitas desbloquearlo con el PUK)

---

---

## 🤝 Contribuciones

¿Encontraste un problema? ¿Tienes una mejora? **¡Las contribuciones son bienvenidas!**

1. Fork el repositorio
2. Crea tu rama de features (`git checkout -b feature/mejora`)
3. Commit tus cambios (`git commit -m 'Añadir mejora'`)
4. Push a la rama (`git push origin feature/mejora`)
5. Abre un Pull Request

## 📄 Licencia

Documentación de dominio público. Siéntete libre de usar, modificar y compartir.

Este proyecto está bajo licencia MIT. Ver [LICENSE](LICENSE) para más detalles.

---

**⭐ Si te fue útil, dale una estrella al repositorio!**

**📧 Contacto:** [GitHub Issues](https://github.com/xukrutdonut/dnie-ubuntu-24.04/issues)

---

**Última actualización:** Febrero 2026  
**Probado en:** Ubuntu 24.04 LTS  
**Mantenedor:** [@xukrutdonut](https://github.com/xukrutdonut)
