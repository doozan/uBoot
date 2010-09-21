#!/bin/sh

#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# 	Dockstar u-Boot mtd0 Installer v0.3
# 	by Jeff Doozan
#
#   Based on Pogoplug u-Booter Installer v0.2
#   by IanJB, original method and inspiration from aholler:
# 			http://ahsoftware.de/dockstar/
#
# 	This is a script to write a newer u-boot to Pogoplug/DockStar mtd0


UBOOT_MTD0_URL=http://jeff.doozan.com/debian/uboot/uboot.mtd0.kwb
UBOOT_ORIGINAL_URL=http://jeff.doozan.com/debian/uboot/uboot-original-mtd0.kwb
UBOOT_ENV_URL=http://jeff.doozan.com/debian/uboot/uboot.environment
VALID_UBOOT_MD5=http://jeff.doozan.com/debian/uboot/valid-uboot.md5

BLPARAM_URL=http://jeff.doozan.com/debian/uboot/blparam
NANDDUMP_URL=http://jeff.doozan.com/debian/uboot/nanddump
NANDWRITE_URL=http://jeff.doozan.com/debian/uboot/nandwrite
FLASH_ERASE_URL=http://jeff.doozan.com/debian/uboot/flash_erase
FW_PRINTENV_URL=http://jeff.doozan.com/debian/uboot/fw_printenv
FW_CONFIG_URL=http://jeff.doozan.com/debian/uboot/fw_env.config


UBOOT_MTD0=/tmp/uboot.mtd0.kwb
UBOOT_ORIGINAL=/uboot-original-mtd0.kwb
UBOOT_ENV=/tmp/uboot.environment

BLPARAM=/usr/sbin/blparam
NANDDUMP=/usr/sbin/nanddump
NANDWRITE=/usr/sbin/nandwrite
FLASH_ERASE=/usr/sbin/flash_erase
FW_PRINTENV=/usr/sbin/fw_printenv
FW_SETENV=/usr/sbin/fw_setenv
FW_CONFIG=/etc/fw_env.config


verify_md5 ()
{
  local file=$1
  local md5=$2

  local check_md5=$(cat "$md5" | cut -d' ' -f1) 
  local file_md5=$(md5sum "$file" | cut -d' ' -f1)  

  if [ "$check_md5" = "$file_md5" ]; then
    return 0
  else
    return 1
  fi
}

download_and_verify ()
{
  local file_dest=$1
  local file_url=$2

  local md5_dest="$file_dest.md5"
  local md5_url="$file_url.md5"

  # Always download a fresh MD5, in case a newer version is available
  if [ -f "$md5_dest" ]; then rm -f "$md5_dest"; fi
  wget -O "$md5_dest" "$md5_url"
  # retry the download if it failed
  if [ ! -f "$md5_dest" ]; then
    wget -O "$md5_dest" "$md5_url"
    if [ ! -f "$md5_dest" ]; then
      return 1 # Could not get md5
    fi
  fi

  # If the file already exists, check the MD5
  if [ -f "$file_dest" ]; then
    verify_md5 "$file_dest" "$md5_dest"
    if [ "$?" -ne "0" ]; then
      rm -f "$md5_dest"
      return 0
    else
      rm -f "$file_dest"
    fi
 fi

  # Download the file
  wget -O "$file_dest" "$file_url"
  # retry the download if it failed
  verify_md5 "$file_dest" "$md5_dest"
  if [ "$?" -ne "0" ]; then  
    # Download failed or MD5 did not match, try again
    if [ -f "$file_dest" ]; then rm -f "$file_dest"; fi
    wget -O "$file_dest" "$file_url"
    verify_md5 "$file_dest" "$md5_dest"
    if [ "$?" -ne "0" ]; then  
      rm -f "$md5_dest"
      return 1
    fi
  fi

  rm -f "$md5_dest"
  return 0
}

install ()
{
  local file_dest=$1
  local file_url=$2   
  local file_pmask=$3  # Permissions mask
  
  echo "# checking for $file_dest..."

  # Install target file if it doesn't already exist
  if [ ! -s "$file_dest" ]; then
    echo ""
    echo "# Installing $file_dest..."

    # Check for read-only filesystem by testing
    #  if we can delete the existing 0 byte file
    #  or, if we can create a 0 byte file
    local is_readonly=0
    if [ -f "$file_dest" ]; then
      rm -f "$file_dest" 2> /dev/null
    else
      touch "$file_dest" 2> /dev/null
    fi
    if [ "$?" -ne "0" ]; then
      local is_readonly=0
      mount -o remount,rw /
    fi
    rm -f "$file_dest" 2> /dev/null
        
    download_and_verify "$file_dest" "$file_url"
    if [ "$?" -ne "0" ]; then
      echo "## Could not install $file_dest from $file_url, exiting."
      if [ "$is_readonly" = "1" ]; then
        mount -o remount,ro /
      fi
      exit 1
    fi

    chmod $file_pmask "$file_dest"

    if [ "$is_readonly" = "1" ]; then
      mount -o remount,ro /
    fi

    echo "# Successfully installed $file_dest."
  fi

  return 0
}



if [ "$1" != "--noprompt" ]; then

  echo ""
  echo ""
  echo "!!!!!!  DANGER DANGER DANGER DANGER DANGER DANGER  !!!!!!"
  echo ""
  echo "If you lose power to your device while running this script,"
  echo "it could be left in an unusable state."
  echo ""
  echo "This script will replace the bootloader on /dev/mtd0."
  echo ""
  echo "This installer will only work on a Seagate Dockstar or Pogoplug Pink."
  echo "Do not run this installer on any other device."
  echo ""
  echo "By typing ok, you agree to assume all liabilities and risks "
  echo "associated with running this installer."
  echo ""
  echo -n "If you agree, type 'ok' and press ENTER to continue: "

  read IS_OK
  if [ "$IS_OK" != "OK" -a "$IS_OK" != "Ok" -a "$IS_OK" != "ok" ];
  then
    echo "Exiting. uBoot was not installed."
    exit 1
  fi

fi


if [ -d /usr/local/cloudengines/ ]; then
  echo ""
  echo ""
  echo ""
  echo "DISABLE POGOPLUG SERVICES"
  echo ""
  echo "The pogoplug service includes an auto-update feature which could"
  echo "be used to cripple or disable your device.  It is recommended"
  echo "that you disable this service."
  echo ""
  echo "NOTE: The pogoplug service is proprietary software"
  echo "created by Cloud Engines.  It is not available for use"
  echo "in other distributions and will not be available in"
  echo "your new linux installation even if you choose not to disable it."
  echo ""
  echo -n "Would you like to disable the pogoplug services? [Y/n] "
  read DISABLE
  if [ "$DISABLE" = "" -o "$DISABLE" = "y" -o "$DISABLE" = "Y" ];
  then

    echo "Applying fixes to the pogoplug environment..."

    mount -o rw,remount /

    # Add /sbin to the path and cleanup the shell prompt
    if [ ! -f /root/.bash_profile ]; then 
      echo -e \
  "export PS1='\h:\w\$ '
  export PATH='/usr/bin:/bin:/sbin'
  " > /root/.bash_profile
    fi

    chmod go+w /dev/null

    # Re-enable dropbear (updated dockstars only)
    sed -i 's/^#\/usr\/sbin\/dropbear/\/usr\/sbin\/dropbear/' /etc/init.d/db > /dev/null 2>&1

    echo "Disabling the pogoplug service..."
    # Comment out the line that starts hmbgr.sh
    sed -i 's/^\/etc\/init.d\/hbmgr.sh start/#Uncomment the line below to enable the pogoplug service\n#\/etc\/init.d\/hbmgr.sh start/' /etc/init.d/rcS
    
    mount -o ro,remount /

    echo "Done fixing pogoplug environment."
    echo ""
  fi

  install "$UBOOT_ORIGINAL"   "$UBOOT_ORIGINAL_URL"    644
fi


install "$BLPARAM"          "$BLPARAM_URL"           755
install "$NANDWRITE"        "$NANDWRITE_URL"         755
install "$NANDDUMP"         "$NANDDUMP_URL"          755
install "$FLASH_ERASE"      "$FLASH_ERASE_URL"       755
install "$FW_PRINTENV"      "$FW_PRINTENV_URL"       755
install "$FW_CONFIG"        "$FW_CONFIG_URL"         644
if [ ! -f "$FW_SETENV" ]; then
  ln -s "$FW_PRINTENV" "$FW_SETENV" 2> /dev/null
  if [ "$?" -ne "0" ]; then
    mount -o remount,rw /
    ln -s "$FW_PRINTENV" "$FW_SETENV"
    mount -o remount,ro /
  fi
fi





# Attempt to auto-detect the device by looking at the existing bootcmd parameters
#
# If the bootcmd parameters matches a known default string, we assume the device is clean
#
# If the bootcmd paramater does not match a known string, but instead has a bootcmd_original
# string that matches a known default, then we assume the device is modified and check
# for the existance of our bootloader
#
# If neither the bootcmd nor the bootcmd_original strings match a known default, we ask the user
# to select his device

echo ""
echo -n "# Attempting to auto-detect your device..."

dockstar='nand read.e 0x800000 0x100000 0x300000; setenv bootargs $(console) $(bootargs_root); bootm 0x800000'
pogoplug1='nand read 0x2000000 0x100000 0x200000; setenv bootargs $(console) $(bootargs_root); bootm 0x2000000'
pogoplug2='nand read.e 0x800000 0x100000 0x200000; setenv bootargs $(console) $(bootargs_root); bootm 0x800000'

bootcmd=`$BLPARAM | grep "^bootcmd=" | cut -d'=' -f 2-`
bootcmd_original=`$BLPARAM | grep "^bootcmd_original=" | cut -d'=' -f 2-`

if   [ "$bootcmd" = "$dockstar" ]; then
  echo "Dockstar detected"
  bootcmd_original=$bootcmd
elif [ "$bootcmd" = "$pogoplug1" ]; then
  echo "Pogoplug v1 detected"
  bootcmd_original=$bootcmd
  echo ""
  echo "This installer is not compatible with your device."
  exit 1
elif [ "$bootcmd" = "$pogoplug1" ]; then  
  echo "Pogoplug v2 detected"
  bootcmd_original=$bootcmd

elif [ "$bootcmd_original" = "$dockstar" ]; then
  echo "Dockstar with modified bootcmd detected"
elif [ "$bootcmd_original" = "$pogoplug1" ]; then
  echo "Pogoplug v1 with modified bootcmd detected"
  echo ""
  echo "This installer is not compatible with your device."
  exit 1
elif [ "$bootcmd_original" = "$pogoplug1" ]; then  
  echo "Pogoplug v2 with modified bootcmd detected"

# Auto detect failed, ask the user what device he has
else
  echo "failed!"

  bootcmd_original=

  while [ "$bootcmd_original" = "" ]; do
    echo ""
    echo "############################################"
    echo "Your device could not be auto-detected."
    echo ""
    echo "You must be using a Seagate Dockstar or Pogoplug Pink to run this installer."
    echo ""
    echo "What device are you using? Type the number of your device and press ENTER."
    echo "1 - DockStar"
    echo "2 - Pogoplug v2 - Pink"
    echo "3 - Other"
    read device

    if [ "$device" = "1" ]; then
      echo "Selected Dockstar"
      bootcmd_original=$dockstar
    elif [ "$device" = "2" ]; then
      echo "Selected Pogoplug v2"
      bootcmd_original=$pogoplug2
    elif [ "$device" = "3" ]; then
      echo "Selected Other Device, exiting"
      exit 1
    else
      echo "Invalid Input"
    fi
  done
  
fi


UPDATE_UBOOT=1

# If this is not a clean device, check to see if our bootloader is already installed

if [ "$bootcmd" != "$bootcmd_original" ]; then
  echo ""
  echo "# Checking for existing uBoot on mtd0..."
  wget -O "$UBOOT_MTD0.md5" "$UBOOT_MTD0_URL.md5"

  # dump the area of mtd3 where an existing uboot would be to /tmp/mtd3.uboot
  $NANDDUMP -no -l 0x80000 -f /tmp/uboot-mtd0-dump /dev/mtd0
  
  verify_md5 "/tmp/uboot-mtd0-dump" "$UBOOT_MTD0.md5"
  if [ "$?" -ne "0" ]; then
  if [ 1 ]; then
    rm "/tmp/valid-uboot.md5" 2> /dev/null
    wget -O "/tmp/valid-uboot.md5" "$VALID_UBOOT_MD5"
    
    CURRENT_UBOOT_MD5=$(md5sum "/tmp/uboot-mtd0-dump" | cut -d' ' -f1)
    UBOOT_IS_KNOWN=$(grep $CURRENT_UBOOT_MD5 /tmp/valid-uboot.md5)
    if [ "$UBOOT_IS_KNOWN" != "" ]; then
      rm "/tmp/valid-uboot.md5"
      echo "## Valid uBoot detected on mtd0."
    else
      rm "/tmp/valid-uboot.md5"
      echo "## Unknown uBoot detected on mtd0: $CURRENT_UBOOT_MD5"
      echo "##"
      if [ "$1" != "--no-uboot-check" ]; then
        echo "## The installer could not detect the version of your current uBoot"
        echo "## This may happen if you have installed a different uBoot on"
        echo "## /dev/mtd0 or if you have bad blocks on /dev/mtd0"
        echo "##"
        echo "## If you have bad blocks on mtd0, you should not try to install uBoot."
        echo "##"
        echo "## If you have installed a diffirent uBoot on mtd0, and understand the"
        echo "## risks, you can re-run the installer with the --no-uboot-check parameter"
        echo "##"
        echo "## Installation cancelled."
        exit 1
      else
        echo "## --no-uboot-check flag detected, continuing installation"
      fi
    fi
  else
    rm "$UBOOT_MTD0.md5"
    echo "## The newest uBoot is already installed on mtd0."
    UPDATE_UBOOT=0
  fi
  
fi


# uBoot is not yet installed to mtd3,
# download the new uBoot and install it

if [ "$UPDATE_UBOOT" = "1" ]; then

  echo ""
  echo "# Installing uBoot"

  download_and_verify "$UBOOT_MTD0" "$UBOOT_MTD0_URL"
  if [ "$?" -ne "0" ]; then
    echo "## uBoot could not be downloaded, or the MD5 does not match."
    echo "## Exiting. No changes were made to mtd0."
    exit 1
  fi
  
  # Write new uBoot to mtd0
  # Erase the first 512k
  $FLASH_ERASE /dev/mtd0 0 4 

  $NANDWRITE /dev/mtd0 $UBOOT_MTD0

  # dump mtd3 and compare the checksum, to make sure it installed properly  
  $NANDDUMP -no -l 0x80000 -f /tmp/mtd0.uboot /dev/mtd0
  echo "## Verifying new uBoot..."
  wget -O "$UBOOT_MTD0.md5" "$UBOOT_MTD0_URL.md5"
  
  verify_md5 "/tmp/mtd0.uboot" "$UBOOT_MTD0.md5"
  if [ "$?" -ne "0" ]; then
    rm -f "$UBOOT.md5"
    echo "##"
    echo "##"
    echo "## VERIFICATION FAILED!"
    echo "##"
    echo "## uBoot was not properly installed to mtd0."
    echo "##"
    echo "##"
    echo "## YOUR DEVICE MAY BE IN AN UNUSABLE STATE."
    echo "## DO NOT REBOOT OR POWER OFF YOUR DEVICE"
    echo "##"
    echo "##"
    echo "## Make a backup of /tmp/uboot-mtd0-dump someplace safe and"
    echo "## then re-run this installer."
    exit 1
  else
    echo "# Verified successfully!"
  fi
  rm -f "$UBOOT_MTD0.md5"
  
fi

UPDATE_UBOOT_ENVIRONMENT=$UPDATE_UBOOT

if [ "$UPDATE_UBOOT" != "1" -a "$1" != "--noprompt" ]; then
  echo ""
  echo ""
  echo "You are already running the latest uBoot."
  echo -n "Would you like to reset the uBoot environment? [N/y] "
  read PROMPT
  if [ "$PROMPT" = "y" -o "$PROMPT" = "Y" ]; then
    UPDATE_UBOOT_ENVIRONMENT=1
  fi
fi

if [ "$UPDATE_UBOOT_ENVIRONMENT" = "1" ]; then
  echo ""
  echo "# Installing uBoot environment"

  # Preserve the MAC address 
  ENV_ETHADDR=`$FW_PRINTENV ethaddr | cut -d'=' -f 2-`
  if [ "$ENV_ETHADDR" = "" ]; then
    ENV_ETHADDR=`$BLPARAM | grep "^ethaddr=" | cut -d'=' -f 2-`
  fi

  # Preserve the 'rescue_installed' setting
  ENV_RESCUE_INSTALLED=`$FW_PRINTENV rescue_installed | cut -d'=' -f 2-`
  if [ "$ENV_RESCUE_INSTALLED" = "" ]; then
    ENV_BOOTCMD_RESCUE=`$FW_PRINTENV bootcmd_rescue`
    if [ "$ENV_BOOTCMD_RESCUE" != "" ]; then
      ENV_RESCUE_INSTALLED=1
    fi
  fi

  # Preserve the custom kernel parameters
  ENV_RESCUE_CUSTOM=`$FW_PRINTENV rescue_custom_params | cut -d'=' -f 2-`
  ENV_USB_CUSTOM=`$FW_PRINTENV usb_custom_params | cut -d'=' -f 2-`
  ENV_UBIFS_CUSTOM=`$FW_PRINTENV ubifs_custom_params | cut -d'=' -f 2-`

  # Install the uBoot environment
  download_and_verify "$UBOOT_ENV" "$UBOOT_ENV_URL"
  if [ "$?" -ne "0" ]; then
    echo "## Could not install uBoot environment, exiting"
    exit 1
  fi
  $FLASH_ERASE /dev/mtd0 0xc0000 1
  $NANDWRITE -s 786432 /dev/mtd0 "$UBOOT_ENV"

  echo ""
  echo "# Verifying uBoot environment"

  # Verify the uBoot environment
  $NANDDUMP -of "/tmp/uboot.environment" -s 0xc0000 -l 0x20000 /dev/mtd0
  wget -O "$UBOOT_ENV.md5" "$UBOOT_ENV_URL.md5"
  verify_md5 "/tmp/uboot.environment" "$UBOOT_ENV.md5"
  if [ "$?" -ne "0" ]; then
    rm -f "$UBOOT_ENV.md5"
    echo "## VERIFICATION FAILED!"
    echo "## uBoot environment was not properly written to mtd0.  Please re-run this installer."
    exit 1
  fi
  rm -f "$UBOOT_ENV.md5"

  $FW_SETENV ethaddr $ENV_ETHADDR
  if [ "$ENV_RESCUE_INSTALLED" = "1" ]; then $FW_SETENV rescue_installed $ENV_RESCUE_INSTALLED; fi
  if [ "$ENV_RESCUE_CUSTOM" != "" ]; then $FW_SETENV rescue_custom_params $ENV_RESCUE_CUSTOM; fi
  if [ "$ENV_USB_CUSTOM" != "" ]; then $FW_SETENV rescue_usb_params $ENV_USB_CUSTOM; fi
  if [ "$ENV_UBIFS_CUSTOM" != "" ]; then $FW_SETENV rescue_ubifs_params $ENV_UBIFS_CUSTOM; fi

  $BLPARAM "bootcmd_original=$bootcmd_original" > /dev/null 2>&1
  $BLPARAM 'bootcmd=run bootcmd_original' > /dev/null 2>&1
fi

echo ""
echo "# uBoot installation has completed successfully."

