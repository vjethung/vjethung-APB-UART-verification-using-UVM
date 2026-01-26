class uart_transaction extends uvm_sequence_item;
    bit is_tx;
    rand bit [7:0] data;
    rand uart_data_size_e   data_bit_num;   
    rand uart_stop_size_e   stop_bit_num;   
    rand uart_parity_mode_e parity_en;   
    rand uart_parity_type_e parity_type; 

    rand parity_quality_e   parity_err_inject; 
    rand int                transmit_delay;    

    // TRẠNG THÁI MONITOR error (Status) 
    bit parity_error_detected;
    bit framing_error_detected;

    `uvm_object_utils_begin(uart_transaction)
        `uvm_field_int(data, UVM_ALL_ON)
        `uvm_field_enum(uart_data_size_e, data_bit_num, UVM_ALL_ON)
        `uvm_field_enum(uart_stop_size_e, stop_bit_num, UVM_ALL_ON)
        `uvm_field_enum(uart_parity_mode_e, parity_en, UVM_ALL_ON)
        `uvm_field_enum(uart_parity_type_e, parity_type, UVM_ALL_ON)

        `uvm_field_enum(parity_quality_e, parity_err_inject, UVM_ALL_ON)
        `uvm_field_int(transmit_delay, UVM_ALL_ON | UVM_DEC | UVM_NOCOMPARE)
    `uvm_object_utils_end

    constraint c_data_mask {
        if (data_bit_num == DATA_5BIT) data[7:5] == 0;
        else if (data_bit_num == DATA_6BIT) data[7:6] == 0;
        else if (data_bit_num == DATA_7BIT) data[7] == 0;
        // DATA_8BIT don't need mask
    }

    constraint c_cfg_dist {
        data_bit_num dist {DATA_8BIT := 50, [DATA_5BIT:DATA_7BIT] := 50};
        parity_en  dist {PARITY_DIS := 50, PARITY_EN := 50};
    }

    constraint c_error_default {
        soft parity_err_inject == GOOD_PARITY;
    }
    
    // constraint c_delay {soft transmit_delay inside {[10:60]}; }
    constraint c_delay {soft transmit_delay == 0; }

    function new (string name = "uart_transaction");
      super.new(name);
    endfunction

    function bit calc_parity();
        bit p;
        bit [7:0] masked_data;

        case(data_bit_num)
            DATA_5BIT: masked_data = data & 8'h1F; // 0001 1111
            DATA_6BIT: masked_data = data & 8'h3F; // 0011 1111
            DATA_7BIT: masked_data = data & 8'h7F; // 0111 1111
            DATA_8BIT: masked_data = data & 8'hFF; // 1111 1111
        endcase

        p = ^masked_data; 

        if (parity_type == PARITY_EVEN) 
            return p;      
        else 
            return ~p;     
    endfunction

endclass : uart_transaction