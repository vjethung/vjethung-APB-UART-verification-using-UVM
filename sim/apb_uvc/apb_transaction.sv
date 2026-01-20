class apb_transaction extends uvm_sequence_item;
    // Khai báo các trường dữ liệu giao dịch 
    rand logic [11:0] paddr;
    rand logic [31:0] pwdata;   
    rand logic        pwrite;   
    rand logic [3:0]  pstrb;
    
    // Dữ liệu phản hồi từ DUT 
    logic [31:0]      prdata;
    logic             pslverr;

    `uvm_object_utils_begin(apb_transaction)
        `uvm_field_int(paddr,   UVM_ALL_ON)
        `uvm_field_int(pwdata,  UVM_ALL_ON)
        `uvm_field_int(pwrite,  UVM_ALL_ON)
        `uvm_field_int(pstrb,   UVM_ALL_ON)
        `uvm_field_int(prdata,  UVM_ALL_ON)
        `uvm_field_int(pslverr, UVM_ALL_ON)
    `uvm_object_utils_end

    // Ràng buộc địa chỉ theo spec
    constraint c_paddr_range {
        paddr inside {12'h000, 12'h004, 12'h008, 12'h00C, 12'h010};
    }

    // Chỉ tập trung vào byte lane 0 theo thiết kế hiện tại
    constraint c_pstrb_low_byte {
        pstrb[3:1] == 3'b000;
    }

    function new (string name = "apb_transaction");
        super.new(name);
    endfunction
endclass