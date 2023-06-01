#!/bin/bash

# Help Display function
display_help () {
	echo """Flash the image to all the USB drives with a common name
Usage:
	./bulk_flash_image.sh <image_file.img> [-s <Common string>]
Options:
	<image_file.img>		The image file to flash to multiple devices.
	-s, --string <Common string>	(Optional) The common string in the USB drive names. e.g. \"SanDisk\". If this option is not specified, a list of devices will be printed and ask to enter the common string of the devices.
	-f, --force			Yes to all prompts.
	-b, --block_size		Set the block size of flashing. (Default: Auto determine. If not, 100M)
	-v, --validate			Validate the image of each written drive at the end.
	-d, --debug			Debug output.
	-n, --dryrun			Dry run. It does NOT actually write to the disk.
	-h, --help			Display this help message.
	"""
}

# Get command line arguments
## More safety, by turning some bugs into errors.
## Without `errexit` you don’t need ! and can replace
## ${PIPESTATUS[0]} with a simple $?, but I prefer safety.
set -o errexit -o pipefail -o noclobber -o nounset

## -allow a command to fail with !’s side effect on errexit
## -use return value from ${PIPESTATUS[0]}, because ! hosed $?
! getopt --test > /dev/null 
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo 'I’m sorry, `getopt --test` failed in this environment.'
    exit 1
fi

## option --output/-o requires 1 argument
LONGOPTS=string:,help,debug,dryrun,force,validate,block_size:
OPTIONS=s:hdnfvb:

## -regarding ! and PIPESTATUS see above
## -temporarily store output to be able to check for errors
## -activate quoting/enhanced mode (e.g. by writing out “--options”)
## -pass arguments only via   -- "$@"   to separate them correctly
! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    # e.g. return value is 1
    #  then getopt has complained about wrong arguments to stdout
    exit 2
fi
## read getopt’s output this way to handle the quoting right:
eval set -- "$PARSED"

imageFile=- commonString=- debug=n dryrun=n force=n validate=n block_size=-
## split the command
while true; do
	case "$1" in
		-h|--help)
			display_help
			shift
			exit 0
			;;
		-s|--string)
			commonString="$2"
			shift 2
			;;
		-d|--debug)
			debug=y
			shift
			;;
		-n|--dryrun)
			dryrun=y
			shift
			;;
		-f|--force)
			force=y
			shift
			;;
		-v|--validate)
			validate=y
			shift
			;;
		-b|--block_size)
			block_size="$2"
			shift 2
			;;
		--)
			shift
			break
			;;
		*)
			echo "Invalid arguments"
			display_help
			exit 3
			;;
	esac
done

## handle non-option arguments
if [[ $# -ne 1 ]]; then
    echo "$0: Image file is required."
    display_help
    exit 4
fi

## Get the image file argument
imageFile=$1

## Debug information
if [[ $debug == y ]]; then
	echo "commonString: $commonString, imageFile: $imageFile, block_size: $block_size"
fi

# Check whether the image file exists
if ! [[ -f "${imageFile}" ]]; then
	echo "The image file does not exist!"
	exit 2
fi

# Check the file type is image file
if ! [[ "$(file ${imageFile})" == *"DOS/MBR boot sector"* ]]; then
	echo "The input file is NOT the IMG file type!"
	echo "Is it truely the IMG file? Try to rename it without any space and special characters."
	exit 2
fi

sudo echo

pkg="dcfldd"
if dpkg-query -W -f'${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
	if [[ $debug == y ]]; then
		echo "dcfldd installed"
	fi
else
	echo "The package, dcfldd, is not installed! It will be installed..."
	sudo apt-get install dcfldd -y
fi
set +e

# Ask to unplug and replug the USB hub
if [[ $force == n ]]; then # Skip the prompt if force
	echo "Please unplug and replug the USB hub to ensure all the devices are properly refreshed."
	read -p "Continue? (Y/n): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] || $confirm == "" ]] || exit 1
fi

# Display image file information
echo """The image file to be flashed:
--> $imageFile
	"""

# Display all USB devices if --string option is not given
if [[ $commonString == - ]]; then
	echo "The following list all the connected drive path:"
	echo
	ls /dev/disk/by-id/ -1
	## Ask for the common string input:
	echo
	echo "What is the common string that can most describe this kind of device?"
	read -p "Enter here: " commonString
	if [[ $debug == y ]]; then
		echo "commonString: $commonString"
	fi
fi

# Check whether the common String is empty
if [[ $commonString == "" ]]; then
	echo "Please enter the common string!"
	exit 1
fi

# Find all the disk according to the common string in all USB drive names
x=$(find /dev/disk/by-id/ -maxdepth 1 -name "*${commonString}*" -print)
x=($x)

disks=()

for i in "${x[@]}"; do
#	echo "--> $i"

	# Check whether the string contains "part" at the end
	#  , which indicates it's not a partition but a drive.
	if [[ ${i} != *"part"*  ]]; then
		disks+=(${i})
	fi
done

# Check whether the disk list is empty
if [ ${#disks[@]} -gt 0 ]; then
	if [[ ${debug} == y ]]; then
		echo "disks array is not empty"
	fi
else
	echo  "The disks are not found. Please enter a valid common string!"
	exit 1
fi

# Find all the disk partitions and all the disks with partitions
partitions=()
disks_with_partitions=()
disks_without_partitions=()
for i in "${disks[@]}"; do
	n=0 # Initialise count variable
	## Split the string by "/" and get the last field
	j=${i##*/}

	## Get all disks and partitions
	k=$(find /dev/disk/by-id/ -maxdepth 1 -name "*${j}*" -print)
	k=($k)
	for l in "${k[@]}"; do
		### Get all disk partitions
		if [[ ${l} == *"part"* ]]; then
			partitions+=(${l})
			n+=1 # append 1
		fi
	done
	## If with partitions
	if [[ n != 0 ]]; then
		disks_with_partitions+=(${i})
	## If without parttions
	elif [[ n == 0 ]]; then
		disks_without_partitions+=(${i})
	fi
done

# Final Confirm the disks to be written
temp_var=$(lsblk -fpls | awk '{print $1}' | grep -A4 `df -P / | awk 'END{print $1}'`)
temp_var1=$(echo ${temp_var} | awk '{print $2}')
if [[ ${temp_var1} == "/dev/"* ]]; then
	device_name=${temp_var1}
else
	temp_var2=$(echo ${temp_var} | awk '{print $3}')
	if [[ ${temp_var2} == "/dev/"* ]]; then
		device_name=${temp_var2}
	else
		temp_var3=$(echo ${temp_var} | awk '{print $4}')
		if [[ ${temp_var3} == "/dev/"* ]]; then
			device_name=${temp_var2}
		fi
	fi
fi

## Check whether the selected disk contains current system
echo "The following disks will be written:"
for i in "${disks[@]}"; do
	echo "--> $i"
	if [[ $(readlink -f ${i}) == ${device_name}* ]]; then
		echo This is the current system disk. Do not use this.
		exit 100
	fi
	echo
done

if [[ $force == n ]]; then # Skip it if force
	read -p "Continue? (Y/n): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] || $confirm == "" ]] || exit 1
fi

# Get the block size of output and input devices
a=($(df -P | grep $(realpath "${disks[0]}")))
obs=$(stat -c "%o" ${a[-1]})
ibs=$(stat -c "%o" "${imageFile}")
if [[ ${debug} == y ]]; then
	echo "ibs: ${ibs}, obs: ${obs}"
fi

# Unmount all related disks and partitions
for i in "${x[@]}"; do
	if [[ $dryrun == n ]]; then
		sudo umount ${i} > /dev/null 2>&1
	fi
done

# Flash to the disk
#sudo dcfldd if=${imageFile} status=on bs=100M of=
if [[ ${block_size} == - ]]; then
	if ! [[ ${obs} == "" || ${ibs} == "" ]]; then
		cmd="sudo dcfldd if=${imageFile} status=on ibs=${ibs} obs=${obs} statusinterval=1"
	else
		cmd="sudo dcfldd if=${imageFile} status=on bs=100M statusinterval=1"
	fi
else
	cmd="sudo dcfldd if=${imageFile} status=on bs=${block_size} statusinterval=1"
fi

for i in "${disks[@]}"; do
	cmd+=" of=${i}"
done

if [[ $dryrun == y ]]; then
	echo "$cmd"
elif [[ $dryrun == n ]]; then
	if [[ $debug == y ]]; then
		echo "$cmd"
	fi
	eval "$cmd"
#	echo "not dryrun"
fi

# Validate the disks to the original image file
if [[ $validate == y ]]; then
	for i in "${disks[@]}"; do
		echo "Validating ${i}"
		cmd="sudo dcfldd vf=${imageFile} if=${i}"
		if [[ ${debug} == y || ${dryrun} == y ]]; then
			echo "${cmd}"
		fi
		if [[ ${dryrun} == n ]]; then
			eval "${cmd}"
		fi
	done
fi
