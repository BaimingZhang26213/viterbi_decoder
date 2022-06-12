# Download the ip_final fold

    All the design source files are in it.

# Build on the zed_fmcs2 platform


Follow stpes in Build FPGA section in the link below.

https://github.com/open-sdr/openwifi-hw/tree/pre-release

Do on the zed_fmcs2 board

**Should change the env parameter LC_NUMERIC="en_BE.UTF-8 to LC_NUMERIC="en_US.UTF-8"**, otherwise will have error when do the ./openwifi.tcl

**If you want to use the other board like zed_fscm2 and antsdr board you need to change the memory of virtual machine to 8GB, otherwise the synthesis will fail.**

untill finished

`source ./ip_repo_gen.tcl`


`source ./openwifi.tcl`

The project generate well



# Modify IP cores

- In Vivado project openwifi_zed_fmcs2:

    In Tcl console:

    `cd ../../ip/openofdm_rx`

   `source ./openofdm_rx.tcl`

    It will generate the openofdm_rx project

- Then in Vivado project openofdm_rx:

  add design sources: ![image](https://user-images.githubusercontent.com/61832922/161838644-88c467b6-6870-4386-aba5-436de05c15b2.png)


    add the nine files under the fold **ip_final/src** 
    >
    >acs.vhd
    >
    >axi4s_buffer.vhd
    >
    >branch_distance.vhd
    >
    >generic_sp_ram.vhd
    >
    >ram_ctrl.vhd
    >
    >recursion.vhd
    >
    >reorder.vhd
    >
    >traceback.vhd
    >
    and add six files under the fold **ip_final/src/dec_viterbi**

    >
    >pkg_components.vhd
    >
    >pkg_helper.vhd
    >
    >pkg_param.vhd
    >
    >pkg_param_derived.vhd
    >
    >pkg_trellis.vhd
    >
    >pkg_types.vhd

- Then move to the libraries tag under the Window _Sources_ 

![image](https://user-images.githubusercontent.com/61832922/161837992-4a446b07-7ee2-4e6a-855e-5ab2d55c8e2a.png)

- Select the pkg_types.vhd and click the `...` button in the Window _Source File Properties_ 

- Set the library to dec_viterbi

![image](https://user-images.githubusercontent.com/61832922/161839654-d5c3b72a-0fc1-4c44-b387-9a99a3413221.png)

- Drag the other five pkg files to the library dec_viterbi

![image](https://user-images.githubusercontent.com/61832922/161840467-652df1be-f783-48a8-8b5f-b0fed140dcb2.png)

- Replace the Xilinx viterbi decoder by our viterbi decoder
  
  1.open ofdm_decoder.v
  
  2.comment the code of Xilinx decoder part
  
  3.add the code below under the Xilinx decoder part
  
        wire [6:0] idle_wire_7bit ; 
        wire m_axis_data_tvalid ;

        dec_viterbi viterbi_inst (
          .aclk(clock),                              // input wire aclk
          .aresetn(~vit_clr),                        // input wire aresetn
          .s_axis_input_tvalid(conv_in_stb_dly),  // input wire s_axis_data_tvalid
          .s_axis_input_tdata({5'b0,conv_in0_dly,5'b0,conv_in1_dly}),    // input wire [15 : 0] s_axis_data_tdata
          .s_axis_input_tuser({6'b0,conv_erase_dly}),    // input wire [7 : 0] s_axis_data_tuser
          .s_axis_input_tready(vit_rdy),  // output wire s_axis_data_tready
          .m_axis_output_tvalid(m_axis_data_tvalid),  // output wire m_axis_data_tvalid
          .m_axis_output_tdata({idle_wire_7bit, conv_decoder_out})   // output wire [7 : 0] m_axis_data_tdata

        );
  

![image](https://user-images.githubusercontent.com/61832922/161842670-5645a2a4-f12e-4944-b6f3-97b31725d592.png)

- Package the IP

  select "package your current project" option
  
 ![image](https://user-images.githubusercontent.com/61832922/161842936-6a6730af-b606-4d7c-b9f1-d452afb5a71d.png)
 
  And select the path below
 
 ![image](https://user-images.githubusercontent.com/61832922/168071678-dec767c8-c008-42cf-8fc9-ceb353b6bb1f.png)
 
  Click Next and select overwrite 
 
- Then back to project _openwifi_zed_fmcs2_
    
    In Tcl console:

    `cd ../../boards/zed_fmcs2`

    `source ./openwifi.tcl`
- Then do synthesis, implementation and generate the bitstream
![image](https://user-images.githubusercontent.com/61832922/168070552-059d835f-3fb6-4129-9fee-c2a1705f8e1f.png)

- After that, we did nothing, just click the "ok"


