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

### ❌ Intento 4: Enlace simbólico + forzar instalación

```bash
sudo ln -sf /lib/x86_64-linux-gnu/libassuan.so.9 /lib/x86_64-linux-gnu/libassuan.so.0
sudo dpkg -i --force-depends libpkcs11-dnie_1.6.8_amd64.deb
```

**Resultado:** El paquete se instala pero la librería sigue sin funcionar:
```
ldd /usr/lib/libpkcs11-dnie.so
  libassuan.so.0: version `LIBASSUAN_1.0' not found
```

Firefox intenta cargar el módulo y falla silenciosamente.

---

## 🎉 Solución final: OpenSC

Tras todas las pruebas, la **solución correcta** es usar **OpenSC** en lugar de `libpkcs11-dnie`.

### ¿Por qué OpenSC?

1. **Nativo en Ubuntu 24.04:** Disponible en repositorios oficiales
2. **Sin dependencias problemáticas:** No requiere libassuan0
3. **Mantenido activamente:** Proyecto de software libre activo
4. **Compatible con DNIe:** Funciona perfectamente con DNI electrónico español
5. **Sin hacks:** No requiere enlaces simbólicos ni forzar instalaciones

### Implementación

```bash
# 1. Instalar OpenSC
sudo apt-get install opensc pcscd pcsc-tools

# 2. Verificar que detecta el DNIe
pkcs11-tool --module /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so --list-slots

# 3. Configurar Firefox
cat > ~/.mozilla/firefox/*.default-release/pkcs11.txt << 'EOF'
library=/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so
name=OpenSC
EOF
```

### Resultado de prueba real

```
Slot 0 (0x0): C3PO LTC31 v2 (00406338) 00 00
  token label        : DNI electrónico
  token manufacturer : DGP-FNMT
  token model        : PKCS#15 emulated
  token flags        : login required, rng, token initialized, PIN initialized
  hardware version   : 0.0
  firmware version   : 0.0
  serial num         : 02088a8513270e
  pin min/max        : 4/16
```

✅ **Funciona perfectamente**

### Ventajas sobre libpkcs11-dnie

| Aspecto | libpkcs11-dnie | OpenSC |
|---------|----------------|---------|
| Disponibilidad | ❌ Requiere descarga manual | ✅ En repositorios oficiales |
| Dependencias | ❌ libassuan0 (no existe) | ✅ Todas disponibles |
| Mantenimiento | ❌ Última actualización 2023 | ✅ Activo (2024+) |
| Compatibilidad | ❌ Requiere hacks | ✅ Funciona nativamente |
| Firefox | ⚠️ Falla silenciosamente | ✅ Funciona correctamente |
| Chrome | ❌ No funciona | ❌ No funciona |

---

## 📊 Comparativa de soluciones evaluadas

### ✅ Opción recomendada: OpenSC
**Ventajas:**
- Instalación simple (1 comando)
- Sin dependencias problemáticas
- Mantenido activamente
- Funciona en Ubuntu 24.04

**Desventajas:**
- Ninguna significativa

### ⚠️ Opción descartada: libpkcs11-dnie + hacks
**Ventajas:**
- Driver "oficial" del gobierno

**Desventajas:**
- Requiere hacks (enlaces simbólicos)
- Instalación forzada con --force-depends
- No funciona correctamente (símbolos incompatibles)
- No mantenido para Ubuntu 24.04

### ❌ Opción descartada: VM con Ubuntu 22.04
**Ventajas:**
- Solución garantizada (libassuan0 existe)

**Desventajas:**
- Overhead de VM
- Complejidad innecesaria
- Uso de recursos

---

## 🔬 Análisis técnico

### Diferencias entre drivers

**libpkcs11-dnie:**
```c
// Requiere símbolos de LIBASSUAN_1.0
LIBASSUAN_1.0 {
  assuan_begin_confidential
  assuan_end_confidential
  ...
}
```

**OpenSC (opensc-pkcs11.so):**
```c
// No depende de libassuan
// Implementación propia de PKCS#11
```

### ¿Por qué Firefox funciona con OpenSC pero no con libpkcs11-dnie?

Firefox carga módulos PKCS#11 dinámicamente. Cuando intenta cargar `libpkcs11-dnie.so`:

1. `dlopen()` intenta cargar la librería
2. El loader busca `libassuan.so.0`
3. Encuentra el enlace simbólico a `libassuan.so.9`
4. Intenta resolver símbolos `LIBASSUAN_1.0`
5. **Falla:** libassuan.so.9 solo tiene `LIBASSUAN_9.0`
6. Firefox falla silenciosamente (no muestra el módulo)

Con OpenSC:
1. `dlopen()` carga `/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so`
2. Todas las dependencias están satisfechas
3. ✅ El módulo se carga correctamente

---

## 📚 Lecciones aprendidas

1. **El driver "oficial" no siempre es la mejor opción**
   - A veces software de terceros (OpenSC) es superior

2. **Compatibilidad hacia adelante es importante**
   - libpkcs11-dnie no se mantiene para nuevas versiones de Ubuntu
   - OpenSC se actualiza regularmente

3. **Los enlaces simbólicos no son soluciones reales**
   - Pueden crear la ilusión de funcionar
   - Pero las incompatibilidades de símbolos persisten

4. **Software libre y mantenido activamente > Software abandonado**
   - Aunque sea oficial del gobierno

---

## 🔮 Recomendaciones futuras

### Para usuarios
- Usar **OpenSC** en Ubuntu 24.04+
- No perder tiempo con libpkcs11-dnie

### Para el gobierno español
1. Actualizar `libpkcs11-dnie` para usar libassuan9
2. O simplemente **recomendar OpenSC** en la documentación oficial
3. Publicar el código fuente de libpkcs11-dnie

---

## 📝 Notas finales

- **Fecha de solución final:** Febrero 2026
- **Versión Ubuntu probada:** 24.04 LTS
- **Lector probado:** C3PO LTC31 v2
- **Driver usado:** OpenSC 0.26.1
- **Estado:** ✅ Funcional y recomendado

---

**Contacto:** Documentación creada por Alberto (@xukrutdonut)  
**Licencia:** MIT
