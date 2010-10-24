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
# 	Dockstar u-Boot mtd0 Installer v0.4
# 	by Jeff Doozan
#
#   Based on Pogoplug u-Booter Installer v0.2
#   by IanJB, original method and inspiration from aholler:
# 			http://ahsoftware.de/dockstar/
#
# 	This is a script to write a newer u-boot to mtd0

# It is NOT a good idea to start your own mirror
# You should leave this as-is
MIRROR=http://jeff.doozan.com/debian/uboot

UBOOT_MTD0_BASE_URL=$MIRROR/files/uboot/uboot.mtd0 # .platform.version.kwb will be appended to this
UBOOT_ENV_URL=$MIRROR/files/environment/uboot.environment
VALID_UBOOT_MD5=$MIRROR/valid-uboot.md5

BLPARAM_URL=$MIRROR/blparam
NANDDUMP_URL=$MIRROR/nanddump
NANDWRITE_URL=$MIRROR/nandwrite
FLASH_ERASE_URL=$MIRROR/flash_erase
FW_PRINTENV_URL=$MIRROR/fw_printenv
FW_CONFIG_URL=$MIRROR/fw_env.config


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
  echo "This installer will only work on the following devices:"
  echo " Seagate GoFlex Net"
  echo " Seagate Dockstar"
  echo " Pogoplug Pink"
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


# Dump existing uBoot and compare it to a database of known versions 

echo ""
echo "# Validating existing uBoot..."

# dump the first 512k of mtd0 to /tmp
$NANDDUMP -no -l 0x80000 -f /tmp/uboot-mtd0-dump /dev/mtd0

wget -O "/tmp/valid-uboot.md5" "$VALID_UBOOT_MD5"

UPDATE_UBOOT=1
UBOOT_PLATFORM=
CURRENT_UBOOT_MD5=$(md5sum "/tmp/uboot-mtd0-dump" | cut -d' ' -f1)
UBOOT_DETAILS=$(grep $CURRENT_UBOOT_MD5 /tmp/valid-uboot.md5)
if [ "$UBOOT_DETAILS" != "" ]; then
  UBOOT_PLATFORM=$(echo $UBOOT_DETAILS | sed 's/^\w* \(\w*\) .*$/\1/')
  UBOOT_VERSION=$(echo $UBOOT_DETAILS | sed 's/^\w* \w* \(.*\)$/\1/')
  echo "## Valid uBoot detected: [$UBOOT_PLATFORM $UBOOT_VERSION] $UBOOT_DETAILS"
else
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
    rm "/tmp/valid-uboot.md5"
    exit 1
  else
    echo "## --no-uboot-check flag detected, continuing installation"

    while [ "$UBOOT_PLATFORM" = "" ]; do
      echo ""
      echo "############################################"
      echo "Your device could not be auto-detected."
      echo ""
      echo "You must be using a device listed below to run this installer."
      echo ""
      echo "What device are you using? Type the number of your device and press ENTER."
      echo "1 - Seagate Dockstar"
      echo "2 - Seagate GoFlex Net"
      echo "3 - Pogoplug v2 - Pink"
      echo "4 - Other"
      read device

      if [ "$device" = "1" ]; then
        echo "Selected Dockstar"
        UBOOT_PLATFORM="dockstar"
        UBOOT_VERSION="unknown"
      elif [ "$device" = "2" ]; then
        echo "Selected Seagate GoFlex Net"
        UBOOT_PLATFORM="goflexnet"
        UBOOT_VERSION="unknown"
      elif [ "$device" = "3" ]; then
        echo "Selected Pogoplug v2 - Pink"
        UBOOT_PLATFORM="pinkpogo"
        UBOOT_VERSION="unknown"
      elif [ "$device" = "4" ]; then
        echo "Selected Other Device, exiting"
        echo "This installer is only compatible with the listed devices."
        exit 1
      else
        echo "Invalid Input"
      fi
    done

  fi
fi

UBOOT_IS_CURRENT=$(echo $UBOOT_VERSION | grep -c current)
if [ "$UBOOT_IS_CURRENT" = "1" ]; then
  echo "## The newest uBoot is already installed on mtd0."
  UPDATE_UBOOT=0
else
  UBOOT_CURRENT=$(grep $UBOOT_PLATFORM /tmp/valid-uboot.md5 | grep current | sed 's/^\w* \w* \(.*\)-current$/\1/')
fi

rm "/tmp/valid-uboot.md5"

# If this is the first time this installer has been run in the
# original Pogoplug enviroment, check if the user wants to disable
# the Pogoplug services
if [ -d /usr/local/cloudengines/ -a ! -e $UBOOT_ORIGINAL ]; then
  killall hbwd
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

  UBOOT_ORIGINAL_URL="$UBOOT_MTD0_BASE_URL.$UBOOT_PLATFORM.original.kwb"
  install "$UBOOT_ORIGINAL"   "$UBOOT_ORIGINAL_URL"    644

  install "$BLPARAM"          "$BLPARAM_URL"           755

  if [ "$UBOOT_PLATFORM" = "pinkpogo"  ]; then BOOTCMD='nand read.e 0x800000 0x100000 0x200000; setenv bootargs $(console) $(bootargs_root); bootm 0x800000'
  # dockstar and goflex have the same bootcmd
  else BOOTCMD='nand read.e 0x800000 0x100000 0x300000; setenv bootargs $(console) $(bootargs_root); bootm 0x800000'
  fi
  $BLPARAM "bootcmd=$BOOTCMD" > /dev/null 2>&1

  # Preserve the MAC address
  ENV_ETHADDR=`$BLPARAM | grep "^ethaddr=" | cut -d'=' -f 2-`
fi



# Download and install the latest uBoot
if [ "$UPDATE_UBOOT" = "1" ]; then

  echo ""
  echo "# Installing uBoot"
  UBOOT_MTD0_URL="$UBOOT_MTD0_BASE_URL.$UBOOT_PLATFORM.$UBOOT_CURRENT.kwb"

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

  # dump mtd0 and compare the checksum, to make sure it installed properly  
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
  if [ "$ENV_ETHADDR" = "" ]; then
    ENV_ETHADDR=`$FW_PRINTENV ethaddr 2> /dev/null | cut -d'=' -f 2-`
  fi

  # Preserve the 'rescue_installed' setting
  ENV_RESCUE_INSTALLED=`$FW_PRINTENV rescue_installed 2> /dev/null | cut -d'=' -f 2-`
  if [ "$ENV_RESCUE_INSTALLED" = "" ]; then
    ENV_BOOTCMD_RESCUE=`$FW_PRINTENV bootcmd_rescue 2> /dev/null`
    if [ "$ENV_BOOTCMD_RESCUE" != "" ]; then
      ENV_RESCUE_INSTALLED=1
    fi
  fi

  # Preserve the arcNumber value
  ENV_ARCNUMBER=`$FW_PRINTENV arcNumber 2> /dev/null | cut -d'=' -f 2-`

  # Preserve the custom kernel parameters
  ENV_RESCUE_CUSTOM=`$FW_PRINTENV rescue_custom_params 2> /dev/null | cut -d'=' -f 2-`
  ENV_USB_CUSTOM=`$FW_PRINTENV usb_custom_params 2> /dev/null | cut -d'=' -f 2-`
  ENV_UBIFS_CUSTOM=`$FW_PRINTENV ubifs_custom_params 2> /dev/null | cut -d'=' -f 2-`

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
  $NANDDUMP -nof "/tmp/uboot.environment" -s 0xc0000 -l 0x20000 /dev/mtd0
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
  if [ "$ENV_ARCNUMBER" != "" ]; then
    $FW_SETENV arcNumber $ENV_ARCNUMBER
  # If there was no arcNumber set, then this is probably a new install.
  # Set the default arcNumber for the platform
  # Note: As of 10/24/2010 everything will default to the SHEEVAPLUG arcNumber (2097)
  # at some point, they should start using the newer dockstar ID (2998) but currently the most 
  # common kernels do not support the Dockstar machine ID 
  else
    $FW_SETENV arcNumber 2097
    echo ""
    echo ""
    echo "# Setting arcNumber to 2097 (SheevaPlug)"
    echo "# Note: if you have a kernel that supports your platform, you should use the proper arcNumber."
    echo "# You can set the correct arcNumber by running the following command:"
    if   [ "$UBOOT_PLATFORM" = "dockstar" ];  then echo $FW_SETENV arcNumber 2998
    elif [ "$UBOOT_PLATFORM" = "goflexnet" ]; then echo $FW_SETENV arcNumber 3089
    elif [ "$UBOOT_PLATFORM" = "pinkpogo" ];  then echo $FW_SETENV arcNumber 2998
    fi
  fi

fi

echo ""
echo "# uBoot installation has completed successfully."

