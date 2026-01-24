// --- APB & UART TYPES DEFINITIONS ---
typedef enum bit [1:0] {
    DATA_5BIT = 2'b00,
    DATA_6BIT = 2'b01,
    DATA_7BIT = 2'b10,
    DATA_8BIT = 2'b11
} uart_data_size_e;

typedef enum bit {
    STOP_1BIT = 1'b0,
    STOP_2BIT = 1'b1
} uart_stop_size_e;

typedef enum bit {
    PARITY_DIS = 1'b0,
    PARITY_EN  = 1'b1
} uart_parity_mode_e;

typedef enum bit {
    PARITY_ODD  = 1'b0,
    PARITY_EVEN = 1'b1
} uart_parity_type_e;

typedef enum bit {COV_ENABLE, COV_DISABLE} cover_e;

typedef enum {
    MON_NONE,    // Không giám sát
    MON_TX_ONLY, // Chỉ giám sát TX (DUT -> UVC)
    MON_RX_ONLY, // Chỉ giám sát RX (UVC -> DUT)
    MON_BOTH     // Giám sát cả hai (Mặc định)
} uart_mon_mode_e;