#include <stdbool.h>
#include <stdint.h>
#include "ble_gap.h"
#include "bsp.h"
#include "nordic_common.h"
#include "nrf_soc.h"
#include "nrf_sdh.h"
#include "nrf_sdh_ble.h"
#include "ble_advdata.h"
#include "app_scheduler.h"
#include "app_timer.h"

#include "nrf_log.h"
#include "nrf_log_ctrl.h"
#include "nrf_log_default_backends.h"

// Radio transmit power in dBm (accepted values are -40, -20, -16, -12, -8, -4, 0, 3, and 4 dBm).
#define TX_POWER                        (-16)

// tag identifying the SoftDevice BLE configuration
#define APP_BLE_CONN_CFG_TAG            1

// Value used as error code on stack dump, can be used to identify stack location on stack unwind.
#define DEAD_BEEF                       0xDEADBEEF

// Shorter advertising interval is supported in Bluetooth 5
#define BLUETOOTH5                      0
#if BLUETOOTH5
#define NON_CONNECTABLE_ADV_INTERVAL    MSEC_TO_UNITS(20, UNIT_0_625_MS)
#else
#define NON_CONNECTABLE_ADV_INTERVAL    MSEC_TO_UNITS(100, UNIT_0_625_MS)
#endif

// Beacon advertisement contents
#define APP_BEACON_INFO_LENGTH          0x17 // Total length of information advertised by the iBeacon
#define APP_ADV_DATA_LENGTH             0x15 // Length of manufacturer specific data in the advertisement.
#define APP_DEVICE_TYPE                 0x02 // 0x02 refers to Beacon.
#define APP_MEASURED_RSSI               0xC3 // The Beacon's measured RSSI at 1 meter distance in dBm.
#define APP_COMPANY_IDENTIFIER          0x004c     // Company identifier for Apple iBeacon
#define APP_MAJOR_VALUE                 0x00, 0xCC // Major value used to identify Beacons.
#define APP_MINOR_VALUE                 0x00, 0x00 // Initial minor value used to identify Beacons.
#define APP_BEACON_UUID                 0x33, 0x01, 0x3f, 0x7f,    0xcb, 0x46, 0x4d, 0xb6,     0xb4, 0xbe, 0x54, 0x2c,   0x31, 0x0a, 0x81, 0xeb
#define MINOR_OFFSET_IN_BEACON_INFO     20

// Minor values to cycle through
#define MIN_MINOR                       1
#define MAX_MINOR                       20

// Length of advertisement pulses
#define DURATION_TO_ADVERTISE_MSECS     3000

// Pauses between advertisements, enough to let devices go back to sleep
#define DURATION_BETWEEN_ADV_MSECS      20000

// Number of iterations
#define NUM_ITERATIONS                  100

static ble_gap_adv_params_t m_adv_params;
static uint8_t              m_advertising = 0;
static uint16_t             m_minor = 0;
static ble_gap_addr_t       m_addr;
static uint8_t              m_beacon_info[APP_BEACON_INFO_LENGTH] = {
        APP_DEVICE_TYPE,
        APP_ADV_DATA_LENGTH,
        APP_BEACON_UUID,
        APP_MAJOR_VALUE,
        APP_MINOR_VALUE,
        APP_MEASURED_RSSI
};
static ble_advdata_manuf_data_t m_manuf_specific_data;

APP_TIMER_DEF(m_advertising_stop_timer);
APP_TIMER_DEF(m_auto_mode_timer);
static uint8_t m_auto_mode = 0;
static int m_iterations = 0;

static void start_auto_mode();
static void stop_auto_mode();

void assert_nrf_callback(uint16_t line_num, const uint8_t *p_file_name) {
    app_error_handler(DEAD_BEEF, line_num, p_file_name);
}

static void advertising_init(void) {
    uint32_t err_code;
    ble_advdata_t advdata;
    ble_advdata_t *scan_response_data = NULL; // no scan response
    uint8_t flags = BLE_GAP_ADV_FLAG_BR_EDR_NOT_SUPPORTED;

    m_manuf_specific_data.company_identifier = APP_COMPANY_IDENTIFIER;
    m_manuf_specific_data.data.p_data = (uint8_t *) m_beacon_info;
    m_manuf_specific_data.data.size = APP_BEACON_INFO_LENGTH;

    // Build and set advertising data.
    memset(&advdata, 0, sizeof(advdata));

    advdata.name_type = BLE_ADVDATA_NO_NAME;
    advdata.flags = flags;
    advdata.p_manuf_specific_data = &m_manuf_specific_data;

    m_beacon_info[MINOR_OFFSET_IN_BEACON_INFO] = (uint8_t)((m_minor >> 16) & 0xff);
    m_beacon_info[MINOR_OFFSET_IN_BEACON_INFO + 1] = (uint8_t)(m_minor & 0xff);

    err_code = ble_advdata_set(&advdata, scan_response_data); // will set on SD sd_ble_gap_adv_data_set
    APP_ERROR_CHECK(err_code);

    // Initialize advertising parameters (used when starting advertising).
    memset(&m_adv_params, 0, sizeof(m_adv_params));

    m_adv_params.type = BLE_GAP_ADV_TYPE_ADV_NONCONN_IND;
    m_adv_params.p_peer_addr = NULL;    // Undirected advertisement.
    m_adv_params.fp = BLE_GAP_ADV_FP_ANY;
    m_adv_params.interval = NON_CONNECTABLE_ADV_INTERVAL;
    m_adv_params.timeout = 0;       // Never time out
}

static void advertising_stop(void) {
    ret_code_t err_code = sd_ble_gap_adv_stop();
    APP_ERROR_CHECK(err_code);

    bsp_indication_set(BSP_INDICATE_ALERT_OFF);
    NRF_LOG_INFO("... stopped advertising");
}

static void advertising_stop_timer_handler(void* p_context) {
    m_advertising = 0;
    advertising_stop();
}

static void advertising_start(void) {
    ret_code_t err_code;

    NRF_LOG_INFO("Starting to advertise at %d ticks for %d ms...", NON_CONNECTABLE_ADV_INTERVAL, DURATION_TO_ADVERTISE_MSECS);
    err_code = sd_ble_gap_adv_start(&m_adv_params, APP_BLE_CONN_CFG_TAG);
    APP_ERROR_CHECK(err_code);

    m_iterations++;
    bsp_indication_set(BSP_INDICATE_ALERT_2);

    // start timer to stop advertising after a short time
    err_code = app_timer_start(m_advertising_stop_timer, APP_TIMER_TICKS(DURATION_TO_ADVERTISE_MSECS), NULL);
    APP_ERROR_CHECK(err_code);
}

static void advertising_start_timer_handler(void* p_context) {
    if (m_iterations < NUM_ITERATIONS) {
        if (!m_advertising) {
            m_advertising = 1;
            m_minor++;
            ret_code_t err_code = sd_ble_gap_addr_set((const ble_gap_addr_t *) (&m_addr));
            APP_ERROR_CHECK(err_code);
            if (m_minor > MAX_MINOR) {
                m_minor = MIN_MINOR;
            }
            NRF_LOG_INFO("Rotating minor to: %d", m_minor);
            advertising_init(); // reinitialize to cycle minor
            advertising_start();
        }
    } else {
        // stop auto mode automatically after the number of iterations has been reached
        stop_auto_mode();
    }
}

static void start_auto_mode() {
    m_auto_mode = 1;
    m_iterations = 0;

    NRF_LOG_INFO("Starting auto-mode");
    bsp_board_led_on(1);
    ret_code_t err_code = app_timer_start(m_auto_mode_timer, APP_TIMER_TICKS(DURATION_BETWEEN_ADV_MSECS), NULL);
    APP_ERROR_CHECK(err_code);
}

static void stop_auto_mode() {
    NRF_LOG_INFO("Stopping auto-mode");
    m_iterations = 0;
    m_auto_mode = 0;
    bsp_board_led_off(1);

    ret_code_t err_code = app_timer_stop(m_auto_mode_timer);
    APP_ERROR_CHECK(err_code);
}

static void ble_stack_init(void) {
    ret_code_t err_code;

    err_code = nrf_sdh_enable_request();
    APP_ERROR_CHECK(err_code);

    // Configure the BLE stack using the default settings.
    // Fetch the start address of the application RAM.
    uint32_t ram_start = 0;
    err_code = nrf_sdh_ble_default_cfg_set(APP_BLE_CONN_CFG_TAG, &ram_start);
    APP_ERROR_CHECK(err_code);

    // Enable BLE stack.
    err_code = nrf_sdh_ble_enable(&ram_start);
    APP_ERROR_CHECK(err_code);

    // Reduce transmission power to the minimum
    err_code = sd_ble_gap_tx_power_set(TX_POWER);
    APP_ERROR_CHECK(err_code);

    // Retrieve MAC address for logging
    err_code = sd_ble_gap_addr_get(&m_addr);
    APP_ERROR_CHECK(err_code);
}

static void log_init(void) {
    ret_code_t err_code = NRF_LOG_INIT(NULL);
    APP_ERROR_CHECK(err_code);
    NRF_LOG_DEFAULT_BACKENDS_INIT();
}

static void bsp_event_callback(bsp_event_t bsp_event) {
    switch (bsp_event) {
        case BSP_EVENT_KEY_0:
            if (!m_auto_mode) {
                start_auto_mode();
            } else {
                stop_auto_mode();
            }
            break;
        default:
            break;
    }
}

static void init_bsp(void) {
    ret_code_t err_code = bsp_init(BSP_INIT_LED | BSP_INIT_BUTTONS, bsp_event_callback);
    APP_ERROR_CHECK(err_code);
    bsp_board_leds_off();
    err_code = bsp_buttons_enable();
    APP_ERROR_CHECK(err_code);
}

static void timer_init(void) {
    ret_code_t err_code = app_timer_init();
    APP_ERROR_CHECK(err_code);

    err_code = app_timer_create(&m_auto_mode_timer, APP_TIMER_MODE_REPEATED, advertising_start_timer_handler);
    APP_ERROR_CHECK(err_code);
    err_code = app_timer_create(&m_advertising_stop_timer, APP_TIMER_MODE_SINGLE_SHOT, advertising_stop_timer_handler);
    APP_ERROR_CHECK(err_code);
}

void sd_state_evt_handler(nrf_sdh_state_evt_t state, void *p_context) {
    switch (state) {
        case NRF_SDH_EVT_STATE_ENABLE_PREPARE:
            break;
        case NRF_SDH_EVT_STATE_ENABLED:
            break;
        case NRF_SDH_EVT_STATE_DISABLE_PREPARE:
            break;
        case NRF_SDH_EVT_STATE_DISABLED:
            break;
    }
}

#define OBSERVER_PRIO 1
NRF_SDH_STATE_OBSERVER(m_state_observer, OBSERVER_PRIO) = {
        .handler   = sd_state_evt_handler,
        .p_context = NULL
};

int main(void) {
    log_init();
    timer_init();
    init_bsp();
    ble_stack_init();
    advertising_init();
    uint8_t *const addr = m_addr.addr;
    NRF_LOG_INFO("Boot completed, MAC address: %02x:%02x:%02x:%02x:%02x:%02x",
                 addr[5], addr[4], addr[3], addr[2], addr[1], addr[0]);
    bsp_board_led_on(0);
    while (true) {
        if (!NRF_LOG_PROCESS()) {
            uint32_t err_code = sd_app_evt_wait();
            APP_ERROR_CHECK(err_code);
        }
    }
}
