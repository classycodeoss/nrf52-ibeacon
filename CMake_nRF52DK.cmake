cmake_minimum_required(VERSION 3.6)

# check if all the necessary toolchain SDK and tools paths have been provided.
if (NOT ARM_NONE_EABI_TOOLCHAIN_PATH)
    message(FATAL_ERROR "The path to the arm-none-eabi-gcc toolchain (ARM_NONE_EABI_TOOLCHAIN_PATH) must be set.")
endif ()

if (NOT NRF5_SDK_PATH)
    message(FATAL_ERROR "The path to the nRF5 SDK (NRF5_SDK_PATH) must be set.")
endif ()

if (NOT NRFJPROG)
    message(FATAL_ERROR "The path to the nrfjprog utility (NRFJPROG) must be set.")
endif ()

macro(nRF52_setup)
    # fix on macOS: prevent cmake from adding implicit parameters to Xcode
    set(CMAKE_OSX_SYSROOT "/")
    set(CMAKE_OSX_DEPLOYMENT_TARGET "")

    # language standard/version settings
    set(CMAKE_C_STANDARD 99)
    set(CMAKE_CXX_STANDARD 98)

    # configure cmake to use the arm-none-eabi-gcc
    set(CMAKE_C_COMPILER "${ARM_NONE_EABI_TOOLCHAIN_PATH}/bin/arm-none-eabi-gcc")
    set(CMAKE_CXX_COMPILER "${ARM_NONE_EABI_TOOLCHAIN_PATH}/bin/arm-none-eabi-c++")
    set(CMAKE_ASM_COMPILER "${ARM_NONE_EABI_TOOLCHAIN_PATH}/bin/arm-none-eabi-gcc")

    include_directories(
            "${NRF5_SDK_PATH}/components/softdevice/common"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/softdevice/common/nrf_sdh.c"
            "${NRF5_SDK_PATH}/components/softdevice/common/nrf_sdh_ble.c"
            "${NRF5_SDK_PATH}/components/softdevice/common/nrf_sdh_soc.c"
            )

    # nRF52 (nRF52-DK => PCA10040)
    set(NRF5_LINKER_SCRIPT "${CMAKE_SOURCE_DIR}/gcc_nrf52.ld")
    set(CPU_FLAGS "-mcpu=cortex-m4 -mfloat-abi=hard -mfpu=fpv4-sp-d16")
    add_definitions(-DNRF52 -DNRF52832 -DNRF52_PAN_64 -DNRF52_PAN_12 -DNRF52_PAN_58 -DNRF52_PAN_54 -DNRF52_PAN_31 -DNRF52_PAN_51 -DNRF52_PAN_36 -DNRF52_PAN_15 -DNRF52_PAN_20 -DNRF52_PAN_55 -DBOARD_PCA10040)
    add_definitions(-DSOFTDEVICE_PRESENT -DS132 -DBLE_STACK_SUPPORT_REQD -DNRF_SD_BLE_API_VERSION=3)
    include_directories(
    	"${NRF5_SDK_PATH}/components/softdevice/s132/headers"
        "${NRF5_SDK_PATH}/components/softdevice/s132/headers/nrf52"
    )
    list(APPEND SDK_SOURCE_FILES
    	"${NRF5_SDK_PATH}/components/toolchain/system_nrf52.c"
    	"${NRF5_SDK_PATH}/components/toolchain/gcc/gcc_startup_nrf52.S"
    )
    set(SOFTDEVICE_PATH "${NRF5_SDK_PATH}/components/softdevice/s132/hex/s132_nrf52_5.0.0_softdevice.hex")
    
    
    set(COMMON_FLAGS "-MP -MD -mthumb -mabi=aapcs -Wall -Werror -O3 -g3 -ffunction-sections -fdata-sections -fno-strict-aliasing -fno-builtin --short-enums ${CPU_FLAGS}")

    # compiler/assambler/linker flags
    set(CMAKE_C_FLAGS "${COMMON_FLAGS}")
    set(CMAKE_CXX_FLAGS "${COMMON_FLAGS}")
    set(CMAKE_ASM_FLAGS "-MP -MD -std=c99 -x assembler-with-cpp")
    set(CMAKE_EXE_LINKER_FLAGS "-mthumb -mabi=aapcs -std=gnu++98 -std=c99 -L ${NRF5_SDK_PATH}/components/toolchain/gcc -T${NRF5_LINKER_SCRIPT} ${CPU_FLAGS} -Wl,--gc-sections --specs=nano.specs -lc -lnosys -lm")
    # note: we must override the default cmake linker flags so that CMAKE_C_FLAGS are not added implicitly
    set(CMAKE_C_LINK_EXECUTABLE "${CMAKE_C_COMPILER} <LINK_FLAGS> <OBJECTS> -o <TARGET>")
    set(CMAKE_CXX_LINK_EXECUTABLE "${CMAKE_C_COMPILER} <LINK_FLAGS> <OBJECTS> -lstdc++ -o <TARGET>")

    include_directories(".")

    # basic board definitions and drivers
    include_directories(
            "${NRF5_SDK_PATH}/components/boards"
            "${NRF5_SDK_PATH}/components/device"
            "${NRF5_SDK_PATH}/components/libraries/util"
            "${NRF5_SDK_PATH}/components/drivers_nrf/hal"
            "${NRF5_SDK_PATH}/components/drivers_nrf/common"
            "${NRF5_SDK_PATH}/components/drivers_nrf/delay"
            "${NRF5_SDK_PATH}/components/drivers_nrf/uart"
            "${NRF5_SDK_PATH}/components/drivers_nrf/clock"
            "${NRF5_SDK_PATH}/components/drivers_nrf/rtc"
            "${NRF5_SDK_PATH}/components/drivers_nrf/gpiote"
    )

    # toolchain specyfic
    include_directories(
            "${NRF5_SDK_PATH}/components/toolchain/"
            "${NRF5_SDK_PATH}/components/toolchain/gcc"
            "${NRF5_SDK_PATH}/components/toolchain/cmsis/include"
    )

    # log
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/experimental_log"
            "${NRF5_SDK_PATH}/components/libraries/experimental_log/src"
            "${NRF5_SDK_PATH}/components/libraries/timer"
    )
    
    # SDK version 14
    include_directories (
            "${NRF5_SDK_PATH}/components/libraries/strerror"
            "${NRF5_SDK_PATH}/components/libraries/experimental_section_vars"
            "${NRF5_SDK_PATH}/components/libraries/experimental_memobj"
            "${NRF5_SDK_PATH}/components/libraries/balloc"
            "${NRF5_SDK_PATH}/external/fprintf"
            "${NRF5_SDK_PATH}/components/libraries/atomic"
    )

    # Segger RTT
    include_directories(
            "${NRF5_SDK_PATH}/external/segger_rtt/"
    )

    # basic board support and drivers
    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/boards/boards.c"
            "${NRF5_SDK_PATH}/components/drivers_nrf/common/nrf_drv_common.c"
            "${NRF5_SDK_PATH}/components/drivers_nrf/clock/nrf_drv_clock.c"
            "${NRF5_SDK_PATH}/components/drivers_nrf/uart/nrf_drv_uart.c"
            "${NRF5_SDK_PATH}/components/drivers_nrf/rtc/nrf_drv_rtc.c"
            "${NRF5_SDK_PATH}/components/drivers_nrf/gpiote/nrf_drv_gpiote.c"
            )

    # drivers and utils
    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/hardfault/hardfault_implementation.c"
            "${NRF5_SDK_PATH}/components/libraries/util/nrf_assert.c"
            "${NRF5_SDK_PATH}/components/libraries/util/app_error.c"
            "${NRF5_SDK_PATH}/components/libraries/util/app_error_weak.c"
            "${NRF5_SDK_PATH}/components/libraries/util/app_util_platform.c"
            "${NRF5_SDK_PATH}/components/libraries/experimental_log/src/nrf_log_backend_serial.c"
            "${NRF5_SDK_PATH}/components/libraries/experimental_log/src/nrf_log_backend_uart.c"
            "${NRF5_SDK_PATH}/components/libraries/experimental_log/src/nrf_log_default_backends.c"
            "${NRF5_SDK_PATH}/components/libraries/experimental_log/src/nrf_log_str_formatter.c"
            "${NRF5_SDK_PATH}/components/libraries/experimental_log/src/nrf_log_frontend.c"
            "${NRF5_SDK_PATH}/components/libraries/experimental_section_vars/nrf_section_iter.c"
            "${NRF5_SDK_PATH}/components/libraries/strerror/nrf_strerror.c"
            "${NRF5_SDK_PATH}/external/fprintf/nrf_fprintf.c"
            "${NRF5_SDK_PATH}/external/fprintf/nrf_fprintf_format.c"
            "${NRF5_SDK_PATH}/components/libraries/experimental_memobj/nrf_memobj.c"
            "${NRF5_SDK_PATH}/components/libraries/balloc/nrf_balloc.c"
            "${NRF5_SDK_PATH}/components/libraries/util/app_util_platform.c"
            "${NRF5_SDK_PATH}/components/libraries/util/sdk_mapped_flags.c"
            )

    # Segger RTT
    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/external/segger_rtt/SEGGER_RTT_Syscalls_GCC.c"
            "${NRF5_SDK_PATH}/external/segger_rtt/SEGGER_RTT.c"
            "${NRF5_SDK_PATH}/external/segger_rtt/SEGGER_RTT_printf.c"
            )

    # Common Bluetooth Low Energy files
    include_directories(
            "${NRF5_SDK_PATH}/components/ble"
            "${NRF5_SDK_PATH}/components/ble/common"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/ble/common/ble_advdata.c"
            "${NRF5_SDK_PATH}/components/ble/common/ble_conn_params.c"
            "${NRF5_SDK_PATH}/components/ble/common/ble_conn_state.c"
            "${NRF5_SDK_PATH}/components/ble/common/ble_srv_common.c"
            )

    # adds target for erasing and flashing the board with a softdevice
    add_custom_target(FLASH_SOFTDEVICE ALL
    		COMMAND echo "FOO: ${NRFJPROG} ${SOFTDEVICE_PATH}"
            COMMAND ${NRFJPROG} --program ${SOFTDEVICE_PATH} -f nrf52 --sectorerase
            COMMAND sleep 0.5s
            COMMAND ${NRFJPROG} --reset -f nrf52
            COMMENT "flashing SoftDevice"
            )

    add_custom_target(FLASH_ERASE ALL
    		
            COMMAND ${NRFJPROG} --eraseall -f nrf52
            COMMENT "erasing flashing"
            )
endmacro(nRF52_setup)

# adds a target for comiling and flashing an executable
macro(nRF52_addExecutable EXECUTABLE_NAME SOURCE_FILES)
    # executable
    add_executable(${EXECUTABLE_NAME} ${SDK_SOURCE_FILES} ${SOURCE_FILES})
    set_target_properties(${EXECUTABLE_NAME} PROPERTIES SUFFIX ".out")
    set_target_properties(${EXECUTABLE_NAME} PROPERTIES LINK_FLAGS "-Wl,-Map=${EXECUTABLE_NAME}.map")

    # additional POST BUILD setps to create the .bin and .hex files
    add_custom_command(TARGET ${EXECUTABLE_NAME}
            POST_BUILD
            COMMAND ${ARM_NONE_EABI_TOOLCHAIN_PATH}/bin/arm-none-eabi-size ${EXECUTABLE_NAME}.out
            COMMAND ${ARM_NONE_EABI_TOOLCHAIN_PATH}/bin/arm-none-eabi-objcopy -O binary ${EXECUTABLE_NAME}.out "${EXECUTABLE_NAME}.bin"
            COMMAND ${ARM_NONE_EABI_TOOLCHAIN_PATH}/bin/arm-none-eabi-objcopy -O ihex ${EXECUTABLE_NAME}.out "${EXECUTABLE_NAME}.hex"
            COMMENT "post build steps for ${EXECUTABLE_NAME}")

    # custom target for flashing the board
    add_custom_target("FLASH_${EXECUTABLE_NAME}" ALL
            COMMAND ${NRFJPROG} --program ${EXECUTABLE_NAME}.hex -f nrf52 --sectorerase
            COMMAND sleep 0.5s
            COMMAND ${NRFJPROG} --reset -f nrf52
            DEPENDS ${EXECUTABLE_NAME}
            COMMENT "flashing ${EXECUTABLE_NAME}.hex"
            )
endmacro()
