#!/bin/sh
#
# Copyright (c) 2015, 2020, The Linux Foundation. All rights reserved.
# Copyright (c) 2023 Qualcomm Innovation Center, Inc. All rights reserved.

# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.

# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

create_cfg_caldata() {
       local brd_name=$(echo $(board_name) | awk -F '-' '{print $2}')
       local brd=$brd_name$(echo $(board_name) | awk -F "$brd_name" '{print$2}')

	awk -F ',' -v apdk='/tmp/' -v mtdblock=$1 -v ahb_dir=$2 -v pci_dir=$3 -v pci1_dir=$4 -v board=$brd '{
		if ($1 == board) {
			print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5
			BDF_SIZE=0
			if ($3 == 0) {
				print "Internal radio"
				cmd ="stat -Lc%s /lib/firmware/" ahb_dir "/bdwlan.b" $2 " 2> /dev/null"
				cmd | getline BDF_SIZE
				close(cmd)
				if(!BDF_SIZE) {
					print "BDF file for Board id " $2 " not found. Using default value"
					BDF_SIZE=131072
				}
				cmd = "dd if="mtdblock" of=" apdk ahb_dir "/caldata.bin bs=1 count=" BDF_SIZE " skip=" $4
				system(cmd)
				cmd = "cp " apdk ahb_dir "/caldata.bin /lib/firmware/" ahb_dir "/"
				system(cmd)
			} else {
				print "PCI radio"
				dir_lib=pci_dir
				if ($3 == 2){
					print "Inside slot instance 2"
					if (pci1_dir != 0) {
						dir_lib=pci1_dir
					}
				}
				cmd ="stat -Lc%s /lib/firmware/" dir_lib "/bdwlan.b" $2 " 2> /dev/null"
				cmd | getline BDF_SIZE
				close(cmd)
				if(!BDF_SIZE) {
					print "BDF file for Board id " $2 " not found. Using default value"
					if (dir_lib == "qcn9224")
						BDF_SIZE=184320
					else
						BDF_SIZE=131072
				}
				cmd = "dd if="mtdblock" of=" apdk dir_lib "/caldata_" $3 ".b" $2 " bs=1 count=" BDF_SIZE " skip=" $4
				system(cmd)
				cmd = "cp " apdk dir_lib "/caldata_" $3 ".b" $2 " /lib/firmware/" dir_lib "/"
				system(cmd)
			}
		}
	}' /ini/ftm.conf

	[ -f /lib/firmware/$2/caldata.bin ] || touch /lib/firmware/$2/caldata.bin
}

do_ftm_conf_override()
{
        #Necessary conditon check, This method will be invoked only for below mentioned RDP's
        #Inside this API, we will update the ftm.conf file with DTS board ID values maintained.
        #This is applicable only for below mentioned RDP's, For other RDP's return [Do nothing]
        local brd_name=$(echo $(board_name) | awk -F '-' '{print $2}')
        local board=$brd_name$(echo $(board_name) | awk -F "$brd_name" '{print$2}')
        local board_id_2g
        local board_id_5g
        local board_id_6g

        case "$board" in
                ap-mi04.3*|ap-mi04.1*|ap-mi01.3*)
                board_id_2g=`hexdump -C /proc/device-tree/soc/wifi@c0000000/qcom,board_id | awk '{print $5}'`
                board_id_5g=`hexdump -C /proc/device-tree/soc/wifi4@f00000/qcom,board_id | awk '{print $5}'`
                board_id_6g=`hexdump -C /proc/device-tree/soc/wifi5@f00000/qcom,board_id | awk '{print $5}'`
                        ;;
                ap-mi01.14)
                board_id_2g=`hexdump -C /proc/device-tree/soc/wifi@c0000000/qcom,board_id | awk '{print $5}'`
                board_id_5g=`hexdump -C /proc/device-tree/soc/wifi1@f00000/qcom,board_id | awk '{print $5}'`
                board_id_6g=`hexdump -C /proc/device-tree/soc/wifi2@f00000/board_id | awk '{print $5}'`
                        ;;
                *)
                        echo "Board name is $board -do_ftm_conf_override API not applicable" > /dev/console && return
                ;;
        esac

        awk -F',' -v board=$board -v board_id_2g=$board_id_2g -v board_id_5g=$board_id_5g -v board_id_6g=$board_id_6g '{
                if ($1 == board) {
                        print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5 "\t" NR
                        lineNumber=NR
                        if ($3 == 0){
                                print "2G slot Instance -lineNumber" lineNumber "DTS board ID - "board_id_2g
                                cmd = "sed -i " lineNumber"s" "\/" $2 "\/" board_id_2g "\/" " /ini/ftm.conf"
                        }
                        if ($3 == 1){
                                print "5G slot Instance -lineNumber" lineNumber "DTS board ID - "board_id_5g
                                cmd = "sed -i " lineNumber"s" "\/" $2 "\/" "00" board_id_5g "\/" " /ini/ftm.conf"
                        }
                        else if($3 == 2)
                        {
                                print "6G slot Instance -lineNumber" lineNumber "DTS board ID - "board_id_6g
                                cmd = "sed -i " lineNumber"s" "\/" $2 "\/" "00" board_id_6g "\/" " /ini/ftm.conf"
                        }
                        system(cmd)
                }
        }' /ini/ftm.conf
}
