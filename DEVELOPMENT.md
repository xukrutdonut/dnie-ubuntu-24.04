# Historial de Desarrollo - DNIe Ubuntu 24.04

## 🎯 Objetivo

Configurar el DNI electrónico español en Ubuntu 24.04 LTS con lector de tarjetas USB.

---

## 🔍 Investigación inicial

### Problema identificado

Ubuntu 24.04 actualizó `libassuan` de la versión 0 a la versión 9, pero el paquete oficial del gobierno (`libpkcs11-dnie`) **sigue dependiendo de `libassuan0`**, que ya no existe en los repositorios.

**Error clave:**
```
/lib/x86_64-linux-gnu/libassuan.so.0: version `LIBASSUAN_1.0' not found (required by /usr/lib/libpkcs11-dnie.so)
```

### Dependencias del paquete

```bash
dpkg -I libpkcs11-dnie_1.6.8_amd64.deb
```

Resultado:
```
Depends: libassuan0 (>= 1.0.0), pcscd, opensc
```

---

## 🧪 Intentos de solución

### ❌ Intento 1: Usar libassuan9 directamente

**Resultado:** Error de símbolos incompatibles
```
version `LIBASSUAN_1.0' not found
```

Las versiones son binariamente incompatibles.

---

### ❌ Intento 2: Buscar libassuan0 en repositorios antiguos

**Intentos:**
- `http://archive.ubuntu.com/ubuntu/pool/main/liba/libassuan/libassuan0_*`
- `http://old-releases.ubuntu.com/ubuntu/pool/main/liba/libassuan/libassuan0_*`
- `http://snapshot.debian.org/archive/debian/*/pool/main/liba/libassuan/libassuan0_*`
- `http://archive.debian.org/debian/pool/main/liba/libassuan/libassuan0_*`

**Resultado:** Todos devuelven 404. El paquete ya no está disponible en ningún mirror oficial.

---

### ❌ Intento 3: Compilar libassuan 1.0.5 desde el código fuente

```bash
wget https://gnupg.org/ftp/gcrypt/libassuan/libassuan-1.0.5.tar.bz2
tar xjf libassuan-1.0.5.tar.bz2
cd libassuan-1.0.5
./configure --prefix=/usr
make
```

**Error:**
```
assuan-io.c:234:10: error: implicit declaration of function 'nanosleep'
```

El código fuente de 2010 no compila con GCC moderno (incompatibilidades de headers POSIX).

---

### ❌ Intento 4: Configurar Google Chrome

```bash
modutil -force -add "DNI-e" -libfile /usr/lib/libpkcs11-dnie.so -dbdir sql:$HOME/.pki/nssdb
```

**Error:**
```
ERROR: Failed to add module "DNI-e". Probable cause : "/lib/x86_64-linux-gnu/libassuan.so.0: version `LIBASSUAN_1.0' not found"
```

Chrome/Chromium usan NSS (Network Security Services) que también intenta cargar la librería, fallando por el mismo motivo.

---

### ✅ Solución final: Enlace simbólico + Firefox

**Estrategia:**
1. Crear enlace simbólico de `libassuan.so.9` → `libassuan.so.0`
2. Forzar instalación de `libpkcs11-dnie` ignorando dependencias
3. Configurar **solo Firefox** (no Chrome)

**Implementación:**

```bash
# Paso 1: Enlace simbólico
sudo ln -sf /lib/x86_64-linux-gnu/libassuan.so.9 /lib/x86_64-linux-gnu/libassuan.so.0

# Paso 2: Instalar forzando dependencias
sudo dpkg -i --force-depends libpkcs11-dnie_1.6.8_amd64.deb

# Paso 3: Configurar Firefox
cat > /tmp/pkcs11.txt << 'EOF'
library=/usr/lib/libpkcs11-dnie.so
name=DNI-e
EOF

for perfil in $(ls ~/.mozilla/firefox/ | grep .default); do
    cp /tmp/pkcs11.txt ~/.mozilla/firefox/$perfil/pkcs11.txt
done
```

**¿Por qué funciona en Firefox pero no en Chrome?**

Firefox usa su propio método de carga de módulos PKCS#11 (archivo `pkcs11.txt`), que **no valida estrictamente las versiones de libassuan**.

Chrome usa `modutil` (de NSS), que **sí valida las versiones** y rechaza el módulo.

---

## 📊 Resultados

### ✅ Funciona

- **Firefox:** Detecta DNIe correctamente
- **Verificación FNMT:** Funciona
- **Lector USB:** Detectado correctamente
- **Servicio pcscd:** Funcional
- **`pcsc_scan`:** Detecta el DNIe

### ❌ No funciona

- **Google Chrome:** Error al cargar módulo NSS
- **Chromium:** Mismo error que Chrome
- **AutoFirma con Chrome:** No funcional

### ⚠️ Funcionamiento parcial

- **AutoFirma con Firefox:** Funciona pero requiere:
  - Solo un perfil de Firefox (`default-release`)
  - Restaurar instalación desde AutoFirma → Herramientas → Restaurar instalación

---

## 🔬 Análisis técnico

### Diferencias entre libassuan 0 y 9

```bash
# Símbolos exportados por libassuan0 (según ldd)
LIBASSUAN_1.0

# Símbolos exportados por libassuan9
LIBASSUAN_9.0
```

Son ABIs completamente diferentes. No son compatibles binariamente.

### ¿Por qué no actualizan libpkcs11-dnie?

El paquete `libpkcs11-dnie_1.6.8` es de **septiembre de 2023** y desde entonces no ha habido actualizaciones.

**Especulación:** El gobierno español no mantiene activamente este paquete. Probablemente usan Ubuntu LTS antiguas (22.04 o anteriores) en sus sistemas.

---

## 🛠️ Alternativas evaluadas (no implementadas)

### Opción A: Máquina virtual

Instalar Ubuntu 22.04 en una VM donde `libassuan0` todavía existe.

**Ventajas:**
- Solución oficial y garantizada
- Funciona con Chrome

**Desventajas:**
- Overhead de VM
- Paso adicional innecesario para uso ocasional

---

### Opción B: Contenedor Docker

Crear un contenedor con Ubuntu 22.04 y acceso al lector USB.

**Problema:** El acceso a dispositivos USB desde Docker requiere privilegios y configuración compleja.

---

### Opción C: Compilar libpkcs11-dnie desde código fuente

No hay código fuente disponible. El paquete `.deb` incluye binarios precompilados.

---

## 📚 Fuentes consultadas

1. **Guía 2tazasdelinux (2025):**
   - https://2tazasdelinux.blogspot.com/2025/04/hacer-funcionar-dnie-en-ubuntu.html
   - Proporciona scripts de configuración
   - **No cubre Ubuntu 24.04** (solo 22.04)

2. **Guía asanzdiego (2024):**
   - https://www.asanzdiego.com/2024/08/configurar-un-lector-de-dni-electronico-en-firefox-con-autofirma-en-ubuntu-version-2024.html
   - Explica configuración manual de Firefox
   - Incluye soluciones para AutoFirma

3. **Página oficial DNIe:**
   - https://www.dnielectronico.es/
   - Descarga de drivers oficiales
   - Sin documentación específica para Ubuntu 24.04

4. **Foros de Ubuntu:**
   - Problemas similares reportados
   - Sin soluciones oficiales

---

## 🎓 Lecciones aprendidas

1. **Dependencias antiguas en software gubernamental:**
   Los paquetes oficiales del gobierno no siguen el ritmo de actualizaciones de Ubuntu.

2. **Firefox vs Chrome en seguridad:**
   Firefox tiene una arquitectura más flexible para módulos de seguridad.

3. **Forzar dependencias es arriesgado pero funcional:**
   `dpkg --force-depends` permite instalar paquetes con dependencias no satisfechas, pero puede romper el sistema si se usa incorrectamente.

4. **Los enlaces simbólicos no siempre son suficientes:**
   Funcionan para Firefox, pero Chrome hace validación más estricta.

---

## 🔮 Futuro

### Si libpkcs11-dnie se actualiza

Idealmente, el gobierno debería:
1. Actualizar `libpkcs11-dnie` para usar `libassuan9`
2. Proporcionar paquetes para Ubuntu 24.04
3. Publicar el código fuente

### Si no se actualiza

Los usuarios tendrán que seguir usando esta solución de enlace simbólico + Firefox.

---

## 📝 Notas finales

- **Fecha de implementación:** Febrero 2026
- **Versión Ubuntu probada:** 24.04 LTS
- **Lector probado:** Super Top microSD card reader (ID 14cd:1212)
- **Estado:** ✅ Funcional con Firefox

---

**Contacto:** Documentación creada por Alberto
**Licencia:** Dominio público
