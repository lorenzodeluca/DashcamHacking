#!/bin/bash
if [ ! -e tmp ]; then
	mkdir tmp
fi
if [ ! -e out ]; then
	mkdir out
fi

function HELP {
	echo "Usage1: dr1300 e|i firmware partname"
	echo "  e: extract partname from firmware"
	echo "  i: repack firmware"	
	echo ""
	echo "Usage2: dr1300 u|r rootfs.dir|customer.dir partname"
	echo "  u: unpack rootfs/customer"
	echo "  r: repack rootfs.dir/customer.dir"
	echo "  * support only squashfs to unpack/repack"
	echo ""
	echo "  **partname: ipl, ipl_cust, uboot, kernel, rootfs, misc, customer"
}
echo "1=" $1
echo "2=" $2
echo "3=" $3
echo "4=" $3

if [ "$1" == "" ] || [ "$2" == "" ]; then 
	HELP
elif [ "$1" == "e" ] && [ "$3" == "" ]; then 
	HELP
elif [ "$1" == "u" ] && [ "$3" == "" ]; then
	HELP
elif [ "$1" == "u" ] && [ "$3" != "" ]; then
	if [ -e $3 ]; then
		unsquashfs -f -d $2 $3
	fi
elif [ "$1" == "r" ] && [ "$3" == "" ]; then
	HELP
elif [ "$1" == "r" ] && [ "$3" != "" ]; then
	if [ -e $2 ]; then
		if [ -e $3 ]; then
			rm -f $3
		fi
		mksquashfs $2 $3 -comp xz
	fi
else 
	if [ -e $2 ]; then
		FW=$2
		for i in ipl ipl_cust uboot kernel rootfs misc customer edog set_config; do
			sector=$(grep -ab "# File Partition: $i" $FW | awk -F ":" '{print $1}' | head -n 1)
			if [ "$i" == "ipl" ]; then
				ipl_sector=$sector
			elif [ "$i" == "ipl_cust" ]; then
				ipl_cust_sector=$sector
			elif [ "$i" == "uboot" ]; then
				uboot_sector=$sector
			elif [ "$i" == "kernel" ]; then
				kernel_sector=$sector
			elif [ "$i" == "rootfs" ]; then
				rootfs_sector=$sector
			elif [ "$i" == "misc" ]; then
				misc_sector=$sector
			elif [ "$i" == "customer" ]; then
				customer_sector=$sector
			elif [ "$i" == "edog" ]; then
				edog_sector=$sector
			elif [ "$i" == "set_config" ]; then
				config_sector=$sector
			fi
		done

		if [ "$ipl_sector" != "" ] && [ "$ipl_cust_sector" != "" ]; then
			dd if=$FW of=tmp/ipl_header.txt bs=1 count=`expr $ipl_cust_sector - $ipl_sector` skip=$ipl_sector status=none
		fi
		if [ "$ipl_cust_sector" != "" ] && [ "$uboot_sector" != "" ]; then
			dd if=$FW of=tmp/ipl_cust_header.txt bs=1 count=`expr $uboot_sector - $ipl_cust_sector` skip=$ipl_cust_sector status=none
		fi
		if [ "$uboot_sector" != "" ] && [ "$kernel_sector" != "" ]; then
			dd if=$FW of=tmp/uboot_header.txt bs=1 count=`expr $kernel_sector - $uboot_sector` skip=$uboot_sector status=none
		fi
		if [ "$kernel_sector" != "" ] && [ "$rootfs_sector" != "" ]; then
			dd if=$FW of=tmp/kernel_header.txt bs=1 count=`expr $rootfs_sector - $kernel_sector` skip=$kernel_sector status=none
		fi
		
		if [ "$misc_sector" == "" ]; then
			if [ "$rootfs_sector" != "" ] && [ "$customer_sector" != "" ]; then
				dd if=$FW of=tmp/rootfs_header.txt bs=1 count=`expr $customer_sector - $rootfs_sector` skip=$rootfs_sector status=none
			fi
			if [ "$customer_sector" != "" ] && [ "$config_sector" != "" ]; then
				dd if=$FW of=tmp/customer_header.txt bs=1 count=`expr $config_sector - $customer_sector` skip=$customer_sector status=none
			fi
		else
			if [ "$rootfs_sector" != "" ] && [ "$misc_sector" != "" ]; then
				dd if=$FW of=tmp/rootfs_header.txt bs=1 count=`expr $misc_sector - $rootfs_sector` skip=$rootfs_sector status=none
			fi
			
			if [ "$misc_sector" != "" ] && [ "$customer_sector" != "" ]; then
				dd if=$FW of=tmp/misc_header.txt bs=1 count=`expr $customer_sector - $misc_sector` skip=$misc_sector status=none
			fi

			if [ "$customer_sector" != "" ] && [ "$edog_sector" != "" ]; then
				dd if=$FW of=tmp/customer_header.txt bs=1 count=`expr $edog_sector - $customer_sector` skip=$customer_sector status=none
			fi			
		fi
		if [ -e tmp/ipl_header.txt ]; then
			ipl_hexsize=`grep SdUpgradeImage tmp/ipl_header.txt | awk -F "0x" '{print $3}'`
			ipl_decsize=`printf "%d" $((16#$ipl_hexsize))`	
			ipl_hexsector=`grep SdUpgradeImage tmp/ipl_header.txt | awk -F "0x" '{print $4}'`
			ipl_decsector=`printf "%d" $((16#$ipl_hexsector))`
		fi
		if [ -e tmp/ipl_cust_header.txt ]; then
			ipl_cust_hexsize=`grep SdUpgradeImage tmp/ipl_cust_header.txt | awk -F "0x" '{print $3}'`
			ipl_cust_decsize=`printf "%d" $((16#$ipl_cust_hexsize))`
			ipl_cust_hexsector=`grep SdUpgradeImage tmp/ipl_cust_header.txt | awk -F "0x" '{print $4}'`
			ipl_cust_decsector=`printf "%d" $((16#$ipl_cust_hexsector))`
		fi
		if [ -e tmp/uboot_header.txt ]; then
			uboot_hexsize=`grep SdUpgradeImage tmp/uboot_header.txt | awk -F "0x" '{print $3}'`
			uboot_decsize=`printf "%d" $((16#$uboot_hexsize))`
			uboot_hexsector=`grep SdUpgradeImage tmp/uboot_header.txt | awk -F "0x" '{print $4}'`
			uboot_decsector=`printf "%d" $((16#$uboot_hexsector))`
		fi
		if [ -e tmp/kernel_header.txt ]; then
			kernel_hexsize=`grep SdUpgradeImage tmp/kernel_header.txt | awk -F "0x" '{print $3}'`
			kernel_decsize=`printf "%d" $((16#$kernel_hexsize))`
			kernel_hexsector=`grep SdUpgradeImage tmp/kernel_header.txt | awk -F "0x" '{print $4}'`
			kernel_decsector=`printf "%d" $((16#$kernel_hexsector))`
		fi
		if [ -e tmp/rootfs_header.txt ]; then
			rootfs_hexsize=`grep SdUpgradeImage tmp/rootfs_header.txt | awk -F "0x" '{print $3}'`
			rootfs_decsize=`printf "%d" $((16#$rootfs_hexsize))`
			rootfs_hexsector=`grep SdUpgradeImage tmp/rootfs_header.txt | awk -F "0x" '{print $4}'`
			rootfs_decsector=`printf "%d" $((16#$rootfs_hexsector))`
		fi
		if [ -e tmp/misc_header.txt ]; then
			misc_hexsize=`grep SdUpgradeImage tmp/misc_header.txt | awk -F "0x" '{print $3}'`
			misc_decsize=`printf "%d" $((16#$misc_hexsize))`
			misc_hexsector=`grep SdUpgradeImage tmp/misc_header.txt | awk -F "0x" '{print $4}'`
			misc_decsector=`printf "%d" $((16#$misc_hexsector))`
		fi
		if [ -e tmp/customer_header.txt ]; then
			customer_hexsize=`grep SdUpgradeImage tmp/customer_header.txt | awk -F "0x" '{print $3}'`
			customer_decsize=`printf "%d" $((16#$customer_hexsize))`
			customer_hexsector=`grep SdUpgradeImage tmp/customer_header.txt | awk -F "0x" '{print $4}'`
			customer_decsector=`printf "%d" $((16#$customer_hexsector))`
		fi
		if [ "$1" == "e" ]; then
			if [ "$3" == "ipl" ]  || [ "$3" == "ipl.es" ]; then
				dd if=$FW of=out/$3 bs=1024 count=`expr $(($ipl_cust_decsector-$ipl_decsector)) / 1024` skip=$(expr $ipl_decsector / 1024) status=none
				echo "Extract $3 success!"
			elif [ "$3" == "ipl_cust" ]  || [ "$3" == "ipl_cust.es" ]; then
				dd if=$FW of=out/$3 bs=1024 count=`expr $(($uboot_decsector-$ipl_cust_decsector)) / 1024` skip=$(expr $ipl_cust_decsector / 1024) status=none
				echo "Extract $3 success!"
			elif [ "$3" == "uboot" ]  || [ "$3" == "uboot.es" ]; then
				dd if=$FW of=out/$3 bs=1024 count=`expr $(($kernel_decsector-$uboot_decsector)) / 1024` skip=$(expr $uboot_decsector / 1024) status=none
				echo "Extract $3 success!"
			elif [ "$3" == "kernel" ]  || [ "$3" == "kernel.es" ]; then
				dd if=$FW of=out/$3 bs=1024 count=`expr $(($rootfs_decsector-$kernel_decsector)) / 1024` skip=$(expr $kernel_decsector / 1024) status=none
				echo "Extract $3 success!"
			elif [ "$3" == "rootfs" ]  || [ "$3" == "rootfs.es" ]; then
				dd if=$FW of=out/$3 bs=1024 count=$(expr $rootfs_decsize / 1024) skip=$(expr $rootfs_decsector / 1024) status=none
				echo "Extract $3 success!"
			elif [ "$3" == "misc" ]  || [ "$3" == "misc.es" ]; then
				if [ "$misc_sector" != "" ]; then
					dd if=$FW of=out/$3 bs=1024 count=$(expr $misc_decsize / 1024) skip=$(expr $misc_decsector / 1024) status=none
					echo "Extract $3 success!"
				else
					echo "Not found partition $3 in $2"
				fi
			elif [ "$3" == "customer" ]  || [ "$3" == "customer.es" ]; then
				dd if=$FW of=out/$3 bs=1024 count=$(expr $customer_decsize / 1024) skip=$(expr $customer_decsector / 1024) status=none
				echo "Extract $3 success!"
			else
				echo "Not found partition $3 in $2"
			fi
			
		elif [ "$1" == "i" ]; then
			cp $FW out/$FW
			if [ -e out/ipl ]; then
				ipl_size=`stat -c "%s" out/ipl`
				if [ $ipl_size = $(($ipl_cust_decsector-$ipl_decsector)) ]; then
					dd if=out/ipl of=out/$FW bs=1024 seek=$(expr $ipl_decsector / 1024) count=`expr $(($ipl_cust_decsector-$ipl_decsector)) / 1024` conv=notrunc status=none
					rm -f out/ipl
				else
					echo "Repack IPL fail, because IPL is not size match!!!"
					echo ""
				fi
			fi
			if [ -e out/ipl_cust ]; then
				ipl_cust_size=`stat -c "%s" out/ipl_cust`
				if [ $ipl_cust_size = $(($uboot_decsector-$ipl_cust_decsector)) ]; then
					dd if=out/ipl_cust of=out/$FW bs=1024 seek=$(expr $ipl_cust_decsector / 1024) count=`expr $(($uboot_decsector-$ipl_cust_decsector)) / 1024` conv=notrunc status=none
					rm -f out/ipl_cust
				else
					echo "Repack IPL_cust fail, because IPL_cust is not size match!!!"
					echo ""
				fi
			fi
			if [ -e out/uboot ]; then
				uboot_size=`stat -c "%s" out/uboot`
				if [ $uboot_size = $(($kernel_decsector-$uboot_decsector)) ]; then
					dd if=out/uboot of=out/$FW bs=1024 seek=$(expr $uboot_decsector / 1024) count=`expr $(($kernel_decsector-$uboot_decsector)) / 1024` conv=notrunc status=none
					rm -f out/uboot
				else
					echo "Repack uboot fail, because uboot is not size match!!!"
					echo ""
				fi
			fi
			if [ -e out/kernel ]; then
				kernel_size=`stat -c "%s" out/kernel`
				if [ $kernel_size = $(($rootfs_decsector-$kernel_decsector)) ]; then
					dd if=out/kernel of=out/$FW bs=1024 seek=$(expr $kernel_decsector / 1024) count=`expr $(($rootfs_decsector-$kernel_decsector)) / 1024` conv=notrunc status=none
					rm -f out/kernel
				else
					echo "Repack kernel fail, because kernel is not size match!!!"
					echo ""
				fi
			fi
			if [ -e out/rootfs ]; then
				rootfs_size=`stat -c "%s" out/rootfs`
				if [ $rootfs_size -le $rootfs_decsize ]; then
					dd if=/dev/zero of=out/$FW bs=1024 seek=$(expr $rootfs_decsector / 1024) count=$(expr $rootfs_decsize / 1024) conv=notrunc status=none
					dd if=out/rootfs of=out/$FW bs=1024 seek=$(expr $rootfs_decsector / 1024) count=$(expr $rootfs_decsize / 1024) conv=notrunc status=none
					rm -f out/rootfs
				else
					echo "Repack rootfs fail, because rootfs is not match!!!"
					echo ""
				fi
			fi
			if [ -e out/misc ]; then
				misc_size=`stat -c "%s" out/misc`
				if [ $misc_size = $misc_decsize ]; then
					dd if=out/rootfs of=out/$FW bs=1024 seek=$(expr $misc_decsector / 1024) count=$(expr $misc_decsize / 1024) conv=notrunc status=none
					rm -f out/rootfs
				else
					echo "Repack misc fail, because misc is not size match!!!"
					echo ""
				fi
			fi
			if [ -e out/customer ]; then
				customer_size=`stat -c "%s" out/customer`
				if [ $customer_size -le $customer_decsize ]; then
					dd if=/dev/zero of=out/$FW bs=1024 seek=$(expr $customer_decsector / 1024) count=$(expr $customer_decsize / 1024) conv=notrunc status=none
					dd if=out/customer of=out/$FW bs=1024 seek=$(expr $customer_decsector / 1024) count=$(expr $customer_decsize / 1024) conv=notrunc status=none
					rm -f out/customer
				else
					echo "Repack rootfs fail, because rootfs is not size match!!!"
					echo ""
				fi
			fi
			fw_time=$(dd if=out/$FW bs=1 count=14 skip=10 status=none)
			now=$(date +"%Y%m%d%I%M%S")
			sed -i "s|$fw_time|$now|g" out/$FW
			echo "Repack Done"
		else
			HELP
		fi
		
	else
		echo "File not found, please enter correct file name"
	fi
fi
rm -rf tmp
