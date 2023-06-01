# Image Bulk Flash Utils

## Bulk Image flashing
`bulk_flash_image.sh` is used to flash the image to a batch of the same type of devices. Its usage is said as follows:
```
$ ./bulk_flash_image.sh -h
Flash the image to all the USB drives with a common name
Usage:
	./bulk_flash_image.sh [-fvdn] <image_file.img> [-s <Common string>]
Options:
	<image_file.img>		The image file to flash to multiple devices.
	-s, --string <Common string>	(Optional) The common string in the USB drive names. e.g. "SanDisk". If this option is not specified, a list of devices will be printed and ask to enter the common string of the devices.
	-f, --force			Yes to all prompts.
	-v, --validate			Validate the image of each written drive at the end.
	-d, --debug			Debug output.
	-n, --dryrun			Dry run. It does NOT actually write to the disk.
	-h, --help			Display this help message.
```

The usage example:
There are 10 devices plugged in. Given that you do not know the common name, run:

```bash
./bulk_flash_image.sh image_to_flash.img
```

It will print all the connected disk devices. For example:

```
...
	
The following list all the connected drive path:

nvme-CT2000P3PSSD8_2226E6439812
nvme-CT2000P3PSSD8_2226E6439812-part1
nvme-CT2000P3PSSD8_2226E6439812-part2
nvme-nvme.c0a9-323232364536343339383132-43543230303050335053534438-00000001
nvme-nvme.c0a9-323232364536343339383132-43543230303050335053534438-00000001-part1
nvme-nvme.c0a9-323232364536343339383132-43543230303050335053534438-00000001-part2
...
```

If the devices you want to write have the common name of "nvme-CT2000P3PSSD8", then enter it in the prompt below:

```
What is the common string that can most describe this kind of device?
Enter here: nvme-CT2000P3PSSD8
```

Then it will proceed with the devices with the given common string in the device name.
Next time if you know the common string, it can be directly given in the command:

```bash
./bulk_flash_image.sh image_to_flash.img -s nvme-CT2000P3PSSD8
```

If you want to suppress the prompt to confirm to continue, `-f` option can be added:

```bash
./bulk_flash_image.sh image_to_flash.img -s nvme-CT2000P3PSSD8 -f
```
