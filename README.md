# HOTD2RE en PortMaster (R36Max con ArkOS4Clones)

Port no oficial de [GitFist/hotd2-re](https://github.com/GitFist/hotd2-re) (reconstrucción nativa de The House of the Dead 2)
para consolas aarch64 con PortMaster. Usa el renderer OpenGL ES 3.0 (`--renderer gles`), pensado para Mali (libmali).

**Estado: sin probar en una consola real.** Se verificó el backend GLES en Mesa llvmpipe y el empaquetado en un PC; el
cross-compile a aarch64, el arranque en ArkOS4Clones, el audio y los controles están por probar. Ver "Qué probar primero".

## Cómo se construye

Hace falta una máquina con red libre (el entorno donde se escribió esto no podía bajar un compilador cruzado).

**Opción A, GitHub Actions (sin instalar nada):** sube estos archivos a tu fork, abre la pestaña *Actions*, elige
*PortMaster aarch64 package* y pulsa *Run workflow*. Al terminar, descarga el artefacto `hotd2-portmaster`.

**Opción B, en un Linux x86_64 (también WSL o un contenedor):**

```
sudo apt-get install cmake ninja-build pkg-config curl xz-utils zip binutils \
     libdrm-dev libgbm-dev libasound2-dev libudev-dev libegl-dev
portmaster/build-aarch64.sh     # compila con zig, apuntando a glibc 2.30 (la de ArkOS); deja portmaster/out/play
portmaster/package.sh           # arma portmaster/out/hotd2-portmaster.zip
```

El script falla si el binario resulta no ser aarch64 o si pide una glibc más nueva que `GLIBC` (por defecto 2.30). Comprueba
la de tu consola con `ldd --version` y, si es otra, ejecuta con `GLIBC=2.xx portmaster/build-aarch64.sh`.

## Instalación en la consola

1. Descomprime `hotd2-portmaster.zip` en la carpeta de ports de la tarjeta (en ArkOS: `/roms/ports/`), de modo que existan
   `HOTD2.sh` y la carpeta `hotd2/`. También puede ir en `/roms/tools/PortMaster/autoinstall/`.
2. Copia **tu** carpeta `game` (del zip *hotd2re-multiplayer-complete* de la release de Windows, no se distribuye aquí porque
   son datos de Sega) dentro de `hotd2/game`, de modo que quede `hotd2/game/Hod2.exe`.
3. Reinicia EmulationStation y lanza *HOTD2* desde Ports. Si algo falla, mira `hotd2/log.txt`.

## Controles (hotd2.gptk, vía gptokeyb)

El juego apunta al puntero del mouse; gptokeyb lo emula: stick derecho o izquierdo mueve la mira, R1/R2 dispara (clic
izquierdo), L1/L2 recarga (clic derecho), Start o A confirman, B o Select vuelven (Esc), la cruceta navega los menús.
Disparar fuera de la pantalla también recarga. Los nombres de teclas del `.gptk` son los de gptokeyb; si tu versión usa
otros, ajusta el archivo.

## Qué probar primero

1. `hotd2/log.txt`: que diga `play: renderer gles (…)` y no un error de EGL o de contexto.
2. Que se vea el menú (si la imagen sale negra o cortada, probar otra resolución con `--width` y `--height` en `HOTD2.sh`).
3. Que la mira se mueva con el stick (si no, revisar `/dev/uinput` y la versión de gptokeyb).
4. Que haya sonido, y los fps en un nivel con muchos enemigos (el renderer es el nativo, sin efectos).
5. Si el juego va lento: bajar la resolución interna en las opciones de pantalla.

## Qué contiene

- `HOTD2.sh`: lanzador de PortMaster. `hotd2.gptk`: mapeo de controles. `port.json`: metadatos (formato sin verificar).
- `play`: el ejecutable aarch64. `scenes/`: definiciones de escenas del repositorio.
- `game/`: vacía, la completas tú.
