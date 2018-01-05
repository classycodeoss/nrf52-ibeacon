# nrf52-ibeacon

Sample iBeacon implementation for the nRF52 chipset.

The build environment uses CMake and assumes an nRF52 Development Kit from Nordic Semiconductor.

# Building the firmware

Create a `CMakeEnv.cmake` file on the same level as `CMakeLists.txt`, with the following contents:

```text
set(ARM_NONE_EABI_TOOLCHAIN_PATH "PATH_TO_ARM_GCC_TOOLCHAIN")
set(NRF5_SDK_PATH "PATH_TO_NORDIC_NRF5_SDK")
set(NRFJPROG "PATH_TO_NRFJPROG")
```

Example using nRF5 SDK 14.2.0, and the most recent version of the GCC ARM toolchain:

```text
set(ARM_NONE_EABI_TOOLCHAIN_PATH "/Users/ahs/local/gcc-arm-none-eabi-7-2017-q4-major")
set(NRF5_SDK_PATH "/Users/ahs/local/nRF5_SDK_14.2.0_17b948a")
set(NRFJPROG "/Users/ahs/local/nRF5x-Command-Line-Tools_9_7_2_OSX/nrfjprog/nrfjprog")
```

Generate makefiles and build out of source tree:
```bash
cmake -H. -B"build"
cmake --build build --target nrf52-ibeacon

```

# Flashing the firmware

```bash
cmake --build build --target FLASH_ERASE
cmake --build build --target FLASH_SOFTDEVICE
cmake --build build --target FLASH_nrf52-ibeacon

```
