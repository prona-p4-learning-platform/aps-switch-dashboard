#!/bin/bash

# TODO: "ansible"ize

# The script assumes to be executed on Ubuntu 20.04 already being installed on an APS BF2556X-1T switch

### BEGIN CONFIG

# Set your home directory here, will be used as the work directory for this script
WORKDIR=~
#WORKDIR=/home/netlabadmin

# script expects to use APS AOT all-in-one bundle that can be downloaded from APS support, e.g., 9.7.0_AOT1.6.1_SAL1.3.5_2.zip --> ${SDE_VERSION}_AOT${AOT_VERSION}_SAL${SAL_VERSION}$AOT_BUNDLE_MINOR_VERSION.zip
SDE_VERSION="9.7.0" # use the version referenced in the all-in-one bundle from APS support site
SDE_BUILD_PROFILE="p4-runtime-tofino.yaml"
AOT_VERSION="1.6.1" # use the version referenced in the all-in-one bundle from APS support site
SAL_VERSION="1.3.5" # use the version referenced in the all-in-one bundle from APS support site
AOT_BUNDLE_MINOR_VERSION="_2"
APS_BSP_VERSION="9.7.0-BF2556_1.0.1" # see porting code for APS switch version in sample settings.yaml of AOT all-in-one bundle
KERNEL_MODULES="- bf_kdrv" # modules that will be loaded before SDE is started, i.e., "- bf_kdrv" or "- bf_kpkt\n  -bf_knet.ko"

GRPCUL_VERSION="1.8.5" # see https://github.com/fullstorydev/grpcurl/releases

SETTINGS_FILE="settings-9.7.yaml"
P4_PROG="pronarepeater"
CMD_TO_GET_P4_PROG="wget https://raw.githubusercontent.com/prona-p4-learning-platform/p4-boilerplate/main/Example1-Repeater/tna/pronarepeater.p4"
P4_BUILD_SCRIPT="p4-build-cmake.sh"
CMD_TO_GET_P4_BUILD_SCRIPT="wget https://raw.githubusercontent.com/prona-p4-learning-platform/aps-switch-dashboard/master/scripts/p4-build-cmake.sh"

SCP_LOCATION="netlabadmin@192.168.73.192:/home/netlabadmin/" # excepted to contain Intel SDE (e.g., bf-sde-9.7.0.tar.gz), AOT bundle (e.g., 9.7.0_AOT1.6.1_SAL1.3.5_2.zip) and p4 source file (e.g., pronarepeater.p4) and p4 build script (e.g., p4-build-cmake.sh)

### END CONFIG

AOT_BUNDLE_FILENAME="${SDE_VERSION}_AOT${AOT_VERSION}_SAL${SAL_VERSION}$AOT_BUNDLE_MINOR_VERSION.zip" # e.g. 9.7.0_AOT1.6.1_SAL1.3.5_2.zip
SCP_LOCATION_AOT_AIO_BUNDLE="netlabadmin@192.168.73.192:/home/netlabadmin/$AOT_BUNDLE_FILENAME" # previously downloaded all-in-one bundle from APS support site
SCP_LOCATION_SDE="netlabadmin@192.168.73.192:/home/netlabadmin/BF/bf-sde-$SDE_VERSION.tgz" # previously downloaded sde from intel

P4_PROG_SRC_FILE="$P4_PROG.p4"
SCP_LOCATION_P4_PROG_SRC_FILE="netlabadmin@192.168.73.192:/home/netlabadmin/$P4_PROG_SRC_FILE"
P4_BUILD_SCRIPT="p4-build-cmake.sh"
SCP_LOCATION_P4_BUILD_SCRIPT="netlabadmin@192.168.73.192:/home/netlabadmin/$P4_BUILD_SCRIPT" .
#SCP_LOCATION_BSP="netlabadmin@192.168.73.192:/home/netlabadmin/scp/bf-reference-bsp-$SDE_VERSION.tgz" # previously downloaded reference bsp from intel, only needed for sde <9.7.0

if [ ! -d "$WORKDIR" ]; then
  echo "Your workdir ${WORKDIR} does not exist"
  exit 1
fi
cd $WORKDIR

sudo apt -y update
sudo apt -y upgrade

mkdir BF
mkdir bsp

# copy AOT all-in-one bundle to workdir
scp -o "StrictHostKeyChecking no" $SCP_LOCATION_AOT_AIO_BUNDLE
# copy intel sde to workdir 
scp -o "StrictHostKeyChecking no" $SCP_LOCATION_SDE ./BF/ # e.g., bf-sde-9.7.0.tgz
if ! [ -z "$SCP_LOCATION_BSP" ] ; then
  scp  -o "StrictHostKeyChecking no" $SCP_LOCATION_BSP ./bsp/ # e.g., bf-reference-bsp-9.7.0.tgz
fi

sudo apt -y install unzip
unzip $AOT_BUNDLE_FILENAME

sudo apt -y install python3 python libusb-1.0-0-dev libcurl4-openssl-dev i2c-tools gcc-8 g++-8
sudo apt -y install python3-pip

cat << EOF > $SETTINGS_FILE
%YAML 1.2
---

# for more information see settings.yaml in AOT directory or https://github.com/APS-Networks/APS-One-touch/blob/master/settings.yaml

PATH_PREFIX: $WORKDIR # enforces SDE location, if omitted home dir is used, leading to the SDE not being found when using sudo

BSP:
  aps_bsp_pkg: /bsp/bf-reference-bsp-$APS_BSP_VERSION #Porting code for APS switch.

BF SDE:
  sde_pkg: /BF/bf-sde-$SDE_VERSION.tgz
  sde_home: /BF/bf-sde-$SDE_VERSION #Path will be automatically created by AOT, this is SDE installation dir path (relative to PATH_PREFIX as every other path in this file). If left blank default is APS-One-touch/<bf-sde-x.y.z>.
  p4studio_build_profile: /BF/bf-sde-$SDE_VERSION/p4studio/profiles/$SDE_BUILD_PROFILE
  #p4_prog: #Leave it blank to start SDE without a P4 program or give p4 program name which is already built in SDE.
  p4_prog: $P4_PROG
  modules: #Following barefoot SDE modules will be loaded before starting SDE.
    $KERNEL_MODULES

SAL :
  sal_home: /APS-One-touch-$AOT_VERSION/release/sal_$SAL_VERSION #Path to directory where SAL artifacts are present
  tp_install: #3rdParty libs path to run the SAL, defaults to <sal_home>/sal_tp_install
  # If executing SAL tests configure
  dut_ips: #One or more <Switch_IP:SAL_gRPC_port> to execute SAL tests upon,
           #SAL should be running on following device address(es) before running any tests.
    - 127.0.0.1:50054
EOF

cd APS-One-touch-$AOT_VERSION/

# SDE : build y/[n]?y
# Do you want install required dependencies? [Y/n]: Y
# BSP : build y/c(clean)/[n]? y
# SDE : start y/[n]? n
echo -e "y\nY\ny\nn" | python3 bf_sde.py ~/settings-9.7.yaml
# sudo required? ...at least used during python3 bf_sde.py

# possible errors during build of BSP?
# CMake Error: The source directory "/home/netlabadmin/bsp/bf-reference-bsp-9.7.0-BF2556_1.0.0" does not exist.
#
# resolution:
# cd /home/netlabadmin/bsp/bf-reference-bsp-9.7.0-BF2556_1.0.1
# cmake .

export SDE=$WORKDIR/BF/bf-sde-$SDE_VERSION
export SDE_INSTALL=$SDE/install

echo "export SDE=$WORKDIR/BF/bf-sde-$SDE_VERSION" >>~/.bashrc
echo "export SDE_INSTALL=$SDE/install" >>~/.bashrc

# is there a better way to get SDE/SDE_INSTALL active for user as well as sudo (root)?
echo "export SDE=$WORKDIR/BF/bf-sde-$SDE_VERSION" | sudo tee -a /root/.bashrc
echo "export SDE_INSTALL=$SDE/install" | sudo tee -a /root/.bashrc

# ugly patch - maybe improve by adding kernel module build to SDE? see also: https://aps-networks.atlassian.net/servicedesk/customer/portal/3/article/1204846593
cd $SDE/pkgsrc/bf-drivers/kdrv/
sed -i '1s;^;cmake_minimum_required(VERSION 3.13)\n;' CMakeLists.txt
cmake . ##You may need to add line like cmake_minimum_required(VERSION 3.13) at the begining od CMakeList.txt##
make ##might throw some errors but check respective kernel directory i.e. ./bf_kdrv/bf_kdrv.ko##
cd bf_kdrv
sudo insmod bf_kdrv.ko
# sudo make install # etc. would be an idea? place kf_kdrv.ko in modules dir etc.? currently breaks, maybe fix build or add kernel modules to build of SDE using
mkdir -p $SDE_INSTALL/lib/modules/
cp $SDE/pkgsrc/bf-drivers/kdrv/bf_kdrv/bf_kdrv.ko $SDE_INSTALL/lib/modules/

cd $WORKDIR

# make provided sal binary executable
chmod +x APS-One-touch-$AOT_VERSION/release/sal_$SAL_VERSION/build/salRefApp

# get libicui18n.so.60 for salRefApp binary, otherwise libicui18n.60 missing in Ubuntu 20.04
echo "deb http://security.ubuntu.com/ubuntu bionic-security main " | sudo tee /etc/apt/sources.list.d/libicui18n-60-src-for-sal.list
sudo apt-get update
sudo apt-get install libicu60

### APS Switch Dashboard

wget https://raw.githubusercontent.com/prona-p4-learning-platform/aps-switch-dashboard/master/start-switch.sh
chmod +x start-switch.sh
sudo apt install tmux

wget https://github.com/fullstorydev/grpcurl/releases/download/v$GRPCUL_VERSION/grpcurl_${GRPCUL_VERSION}_linux_x86_64.tar.gz
tar zxvf grpcurl_${GRPCUL_VERSION}_linux_x86_64.tar.gz
./grpcurl -version

echo "Example to compile $P4_PROG as referenced in sample settings-9.7.yaml..."

# settings: p4_prog: $P4_PROG
$CMD_TO_GET_P4_BUILD_SCRIPT
$CMD_TO_GET_P4_PROG

./$P4_BUILD_SCRIPT $P4_PROG
# second run necessary due to configure?
./$P4_BUILD_SCRIPT $P4_PROG

#2022-01-07 15:52:39.904154 BF_PM ERROR - bf_pm_port_front_panel_port_to_dev_port_get:4245 bf_pm_port_front_pan│2022-01-07 15:52:40.906708 DEBUG BF_PM pm_port_info_get_from_port_hdl:168 pm_port_info_get_from
#el_port_to_dev_port_get: front port 18/0 : not found                                                          │_port_hdl: Unable to get port info: 17/0
#2022-01-07 15:52:39.904232 BF_PM ERROR - bf_pm_port_front_panel_port_to_dev_port_get:4245 bf_pm_port_front_pan│2022-01-07 15:52:40.906772 ERROR BF_PM bf_pm_port_front_panel_port_to_dev_port_get:4245 bf_pm_p
#el_port_to_dev_port_get: front port 33/0 : not found                                                          │ort_front_panel_port_to_dev_port_get: front port 33/0 : not found
#2022-01-07 15:52:39.904309 BF_PM ERROR - bf_pm_port_front_panel_port_to_dev_port_get:4245 bf_pm_port_front_pan│2022-01-07 15:52:39.904283 DEBUG BF_PM pm_port_info_get_from_port_hdl:168 pm_port_info_get_from
#el_port_to_dev_port_get: front port 34/0 : not found                                                          │_port_hdl: Unable to get port info: 34/0
#2022-01-07 15:52:40.906772 BF_PM ERROR - bf_pm_port_front_panel_port_to_dev_port_get:4245 bf_pm_port_front_pan│2022-01-07 15:52:39.904309 ERROR BF_PM bf_pm_port_front_panel_port_to_dev_port_get:4245 bf_pm_p
#el_port_to_dev_port_get: front port 17/0 : not found

# seams resolved after build BSP again? start SDE using python3 bf_sde.py?

# installation finished, APS switch dashboard should be possible to start running the following script in $WORKDIR:
# ./start-switch.sh
